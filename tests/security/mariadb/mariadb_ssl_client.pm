# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run mariadb connect to server with '--ssl' parameter test case
# Maintainer: QE Security <none@suse.de>
# Tags: poo#109154, tc#1767518

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use Utils::Architectures;
use lockapi;

sub run {
    my ($self) = @_;
    my $password = 'my_password';
    my $server_ip = get_var('SERVER_IP', '10.0.2.101');
    my $client_ip = get_var('CLIENT_IP', '10.0.2.102');

    select_console 'root-console';

    # We don't run setup_multimachine in s390x, but we need to know the server and client's
    # ip address, so we add a known ip to NETDEV.
    my $netdev = get_var('NETDEV', 'eth0');
    assert_script_run("ip addr add $client_ip/24 dev $netdev") if (is_s390x);

    zypper_call('in mariadb');
    mutex_wait('MARIADB_SERVER_READY');

    # Try to connect mysql server
    assert_script_run("ping -c 3 $server_ip");
    validate_script_output("mysql --ssl -h $server_ip -u root -p$password -e \"show databases;\";", sub { m/Database/ });

    # Delete the ip that we added if arch is s390x
    assert_script_run("ip addr del $client_ip/24 dev $netdev") if (is_s390x);
}

1;
