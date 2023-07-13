# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Setup mariadb server enviroment and wait client to connect
# Maintainer: QE Security <none@suse.de>
# Tags: poo#109154, tc#1767518

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
    my $db_service = 'mysql';
    my $password = 'my_password';
    my $server_ip = get_var('SERVER_IP', '10.0.2.101');
    my $client_ip = get_var('CLIENT_IP', '10.0.2.102');

    select_console 'root-console';

    # We don't run setup_multimachine in s390x, but we need to know the server and client's
    # ip address, so we add a known ip to NETDEV.
    my $netdev = get_var('NETDEV', 'eth0');
    assert_script_run("ip addr add $server_ip/24 dev $netdev") if (is_s390x);
    systemctl("stop firewalld") if (is_s390x);

    # Install mariadb, edit the config file and start mysql service
    zypper_call('in mariadb');
    assert_script_run('sed -i "/^bind-address.*/c\\bind-address = 0.0.0.0" /etc/my.cnf');
    record_info('mariadb_bind_address', script_output('cat /etc/my.cnf | grep bind-address'));
    systemctl("start $db_service");

    # Update privilege to allow remote access
    my $sql = "GRANT ALL PRIVILEGES ON *.* TO \'root\'@\'%\' IDENTIFIED BY '$password' WITH GRANT OPTION;";
    assert_script_run("mysql -uroot -e \"$sql\"");
    assert_script_run("mysql -uroot -e \"flush privileges;\"");
    record_info('listen_port', script_output('ss -tnlp | grep 3306'));

    mutex_create('MARIADB_SERVER_READY');
    wait_for_children;

    # Stop mariadb service
    systemctl("stop $db_service");

    # Delete the ip that we added if arch is s390x
    assert_script_run("ip addr del $server_ip/24 dev $netdev") if (is_s390x);
}

1;
