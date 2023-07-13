# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run CC 'ipsec' client case
# Maintainer: QE Security <none@suse.de>
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

sub run {
    my ($self) = @_;
    select_console 'root-console';

    # We don't run setup_multimachine in s390x, but we need to know the server and client's
    # ip address, so we add a known ip to NETDEV.
    my $netdev = get_var('NETDEV', 'eth0');
    assert_script_run("ip addr add $atsec_test::client_ip/24 dev $netdev") if (is_s390x);

    assert_script_run("cd $audit_test::test_dir/ipsec_configuration/toe");
    mutex_wait('IPSEC_SERVER_READY');

    # Setup the ipip tunnel to the IPSec gateway and test it
    # 192.168.100.1 is configured in the server by ipsec_setup_tunnel_server.sh
    # We need to check if it's accessible to find the network issue easily.
    assert_script_run("./ipsec_setup_tunnel_toe.sh start $atsec_test::client_ip $atsec_test::server_ip");
    assert_script_run('ping -W1 -c1 192.168.100.1');

    # Install IPSec configuration
    assert_script_run('make install');

    # Test the IPSec connection
    assert_script_run('ipsec start');
    assert_script_run('stime=$(date +\'%H:%M:%S\')');

    # ipsec start can take some time to start charon daemon,
    # so we wait until we get some status output
    my $inc = 0;
    while (scalar(split(/\n/, script_output('ipsec statusall', proceed_on_failure => 1)) <= 5) && $inc < 10) {
        sleep(++$inc);
    }

    assert_script_run('ipsec up ikev2suse');

    # Test the IPSec connection
    assert_script_run('ping -W1 -c1 192.168.250.1');

    # Search for AUDIT SPD/SAD add records
    assert_script_run('ausearch -ts $stime | grep --color -e \'MAC_IPSEC_EVENT\' -e \'SPD-add\' -e \'SAD-add\'');

    assert_script_run('stime=$(date +\'%H:%M:%S\')');

    my $timeout = is_s390x() ? 180 : 90;
    assert_script_run('ipsec down ikev2suse', $timeout);

    # Search for AUDIT SPD/SAD delete records
    assert_script_run('ausearch -ts $stime | grep --color -e \'MAC_IPSEC_EVENT\' -e \'SPD-delete\' -e \'SAD-delete\'');

    # Stop the IPSec service
    assert_script_run('ipsec stop');
}

1;
