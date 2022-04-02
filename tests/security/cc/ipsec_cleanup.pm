# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Cleanup the ipsec test env
# Maintainer: Liu Xiaojing <xiaojing.liu@suse.com>
# Tags: poo#108557

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use audit_test;
use Utils::Architectures;

sub run {
    my ($self) = @_;
    select_console 'root-console';

    my $client_ip = get_var('CLIENT_IP', '10.0.2.102');
    my $netdev = get_var('NETDEV', 'eth0');

    # Stop the ipip tunnel
    assert_script_run("cd $audit_test::test_dir/ipsec_configuration/toe");
    assert_script_run('./ipsec_setup_tunnel_toe.sh stop');

    # Delete the ip that we added if arch is s390x
    assert_script_run("ip addr del $client_ip/24 dev $netdev") if (is_s390x);
}

1;
