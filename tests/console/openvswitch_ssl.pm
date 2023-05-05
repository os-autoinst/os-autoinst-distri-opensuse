# SUSE's openQA tests
#
# Copyright 2017-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: python openvswitch
# Summary: The test to connect openvswitch to openflow with SSL enabled
#
# Maintainer: QE Security <none@suse.de>
# Tags: TC1595181, poo#65375, poo#107134

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';

sub run {
    select_console 'root-console';

    # Install runtime dependencies
    zypper_call("in wget");

    if (is_sle("<=12-SP5")) {
        zypper_call('in python python-base openvswitch');
    } else {
        zypper_call('in python3 python3-base openvswitch');
    }

    # Start openvswitch service
    systemctl('start openvswitch');

    # Create vswitch, virtual tap devices and add them to vswitch
    assert_script_run 'ovs-vsctl add-br ovsbr0';
    assert_script_run 'ip tuntap add mode tap vport1';
    assert_script_run 'ip tuntap add mode tap vport2';
    assert_script_run 'ip link set vport1 up';
    assert_script_run 'ip link set vport2 up';
    assert_script_run 'ovs-vsctl add-port ovsbr0 vport1';
    assert_script_run 'ovs-vsctl add-port ovsbr0 vport2';

    # Prepare private/public keys, and certificates
    for my $pem (qw(ca-cert.pem ca-key.pem server-cert.pem server-key.pem client-cert.pem client-key.pem)) {
        assert_script_run 'wget --quiet ' . data_url("openssl/$pem") . ' -P /etc/openvswitch';
    }

    # Get pox for openflow test
    my $fname = is_sle("<=12-SP5") ? "pox.tar.bz2" : "pox-py3.tar.bz2";
    assert_script_run 'wget --quiet ' . data_url("$fname");
    assert_script_run "tar jvfx $fname";

    # Setup a simulated open-flow controller with POX
    type_string
"pox/./pox.py openflow.of_01 --port=6634 --private-key=/etc/openvswitch/server-key.pem --certificate=/etc/openvswitch/server-cert.pem --ca-cert=/etc/openvswitch/ca-cert.pem 2>&1 | tee /dev/$serialdev &\n";
    die 'pox was not up correctly' unless (wait_serial qr/INFO:core:POX.*is up/ms);
    # Enter to show prompt
    for (1 .. 2) {
        send_key 'ret';
    }

    # Set SSL for openvswitch and connect to open-flow controller (POX)
    assert_script_run 'ovs-vsctl set-ssl /etc/openvswitch/client-key.pem /etc/openvswitch/client-cert.pem /etc/openvswitch/ca-cert.pem';

    # Set controller for the vswitch
    assert_script_run "ovs-vsctl set-controller ovsbr0 \"ssl:127.0.0.1:6634\"";

    # Establish connection needs time and try to check it 3 times in 30s
    for (1 .. 3) {
        sleep 10;
        diag "Trying to check connection: $_ of 3";
        enter_cmd "ovs-vsctl show | tee /dev/$serialdev";
        if (wait_serial qr/Controller "ssl:127\.0\.0\.1:6634".*is_connected: true/ms) {
            last;
        }
        else {
            die 'Connection was failed' if ($_ == 3);
            next;
        }
    }

    # Stop pox
    assert_script_run "ps aux|grep '[p]ox.py'|awk '{print \$2}'|xargs kill";
}

sub test_flags {
    return {fatal => 0};
}

1;
