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
use atsec_test;
use Utils::Architectures;
use lockapi;
use mmapi 'get_children';

sub run {
    my ($self) = @_;
    select_console 'root-console';

    # We don't run setup_multimachine in s390x, but we need to know the server and client's
    # ip address, so we add a known ip to NETDEV.
    my $netdev = get_var('NETDEV', 'eth0');
    assert_script_run("ip addr add $atsec_test::server_ip/24 dev $netdev") if (is_s390x);

    assert_script_run("cd $audit_test::test_dir/ipsec_configuration/server");

    # Create ipip tunnel to the TOE system
    assert_script_run("./ipsec_setup_tunnel_server.sh start $atsec_test::server_ip $atsec_test::client_ip");

    # Install IPSec configuration
    assert_script_run('make install');

    # Start StrongSWAN
    assert_script_run('systemctl start strongswan');

    mutex_create('IPSEC_SERVER_READY');
    my $children = get_children();
    mutex_wait('IPSEC_CLEINT_DONE', (keys %$children)[0]);

    # Stop StrongSWAN
    assert_script_run('systemctl stop strongswan');

    # Delete ipip tunnel
    assert_script_run('./ipsec_setup_tunnel_server.sh stop');
}

1;
