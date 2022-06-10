# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: The server side of postgresql ssl connection test.
# Maintainer: Starry Wang <starry.wang@suse.com> Ben Chou <bchou@suse.com>
# Tags: poo#110233, tc#1769967, poo#112094

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use Utils::Architectures;
use lockapi;
use mmapi 'wait_for_children';

sub run {
    my ($self) = @_;
    my $server_ip = get_var('SERVER_IP', '10.0.2.101');
    my $client_ip = get_var('CLIENT_IP', '10.0.2.102');
    my $pg_hba_config = '/var/lib/pgsql/data/pg_hba.conf';
    my $pg_config = '/var/lib/pgsql/data/postgresql.conf';
    my $passwd = 'postgres';

    select_console 'root-console';

    # We don't run setup_multimachine in s390x, but we need to know the server and client's
    # ip address, so we add a known ip to NETDEV
    my $netdev = get_var('NETDEV', 'eth0');
    assert_script_run("ip addr add $server_ip/24 dev $netdev") if (is_s390x);
    systemctl("stop firewalld");

    # Install postgresql
    zypper_call('in postgresql-server');
    systemctl('start postgresql');

    # Setup key
    assert_script_run('cd /var/lib/pgsql/data');
    assert_script_run('openssl genrsa -out server.key 2048');
    assert_script_run('chmod 400 server.key');
    assert_script_run('chown postgres.postgres server.key');
    assert_script_run('openssl req -new -key server.key -days 3650 -out server.crt -x509 -subj "/C=CN/ST=Beijing/L=Beijing/O=QA/OU=security/CN=example.com"');
    assert_script_run('cp server.crt root.crt');

    # Setup password
    enter_cmd 'su - postgres';
    wait_still_screen(1);
    enter_cmd('psql');
    wait_still_screen(1);
    enter_cmd '\password postgres';
    wait_still_screen(1);
    enter_cmd $passwd;
    wait_still_screen(1);
    enter_cmd $passwd;
    wait_still_screen(1);
    enter_cmd '\q';
    wait_still_screen(1);
    enter_cmd 'exit';
    wait_still_screen(1);
    save_screenshot;

    # Setup configuration
    assert_script_run "echo \"hostssl all all $client_ip/24 trust\" >> $pg_hba_config";
    assert_script_run "echo \"ssl = on\nlisten_addresses = '*'\" >> $pg_config";
    assert_script_run "echo \"ssl_cert_file = 'server.crt'\" >> $pg_config";
    systemctl('restart postgresql');

    # Check the server status
    validate_script_output('ss -tnlp', sub { m/0.0.0.0:5432/ });
    validate_script_output('ps -aux | grep postgresql', sub { m/\/usr\/lib\/postgresql/ });
    save_screenshot;

    mutex_create('POSTGRESQL_SSL_SERVER_READY');
    wait_for_children;

    # Stop postgresql service
    systemctl('stop postgresql');

    # Delete the ip that we added if arch is s390x
    assert_script_run("ip addr del $server_ip/24 dev $netdev") if (is_s390x);
}

1;
