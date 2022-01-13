# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run CC 'ipsec' server case
# Maintainer: Liu Xiaojing <xiaojing.liu@suse.com>
# Tags: poo#101226

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use audit_test;
use Utils::Architectures;
use lockapi;
use mmapi 'wait_for_children';

sub run {
    my ($self) = @_;
    select_console 'root-console';

    my $server_ip = get_var('SERVER_IP', '10.0.2.101');
    my $client_ip = get_var('CLIENT_IP', '10.0.2.102');

    # We don't run setup_multimachine in s390x, but we need to know the server and client's
    # ip address, so we add a known ip to NETDEV.
    my $netdev = get_var('NETDEV', 'eth0');
    assert_script_run("ip addr add $server_ip/24 dev $netdev") if (is_s390x);

    assert_script_run("cd $audit_test::test_dir/ipsec_configuration/server");

    # Create ipip tunnel to the TOE system
    assert_script_run("./ipsec_setup_tunnel_server.sh start $server_ip $client_ip");

    # Install IPSec configuration
    assert_script_run('make install');

    # Start StrongSWAN
    assert_script_run('systemctl start strongswan');

    mutex_create('IPSEC_SERVER_READY');
    wait_for_children;

    # Stop StrongSWAN
    assert_script_run('systemctl stop strongswan');

    # Delete ipip tunnel
    assert_script_run('./ipsec_setup_tunnel_server.sh stop');

    # Delete the ip that we added if arch is s390x
    assert_script_run("ip addr del $server_ip/24 dev $netdev") if (is_s390x);
}

1;
