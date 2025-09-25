# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: python openvswitch
# Summary: The test to connect openvswitch to openflow with SSL enabled
#
# Maintainer: QE Security <none@suse.de>, QE Core <qe-core@suse.de>
# Tags: TC1595181, poo#65375, poo#107134

use base "consoletest";
use testapi;
use utils;
use version_utils 'is_sle';

sub run {
    select_console 'root-console';

    # Install runtime dependencies
    zypper_call("in wget bzip2");

    my $ovs_pkg = is_sle('=15-sp5') ? 'openvswitch3' : 'openvswitch';
    if (is_sle("<=12-SP5")) {
        zypper_call("in python python-base $ovs_pkg");
    } else {
        zypper_call("in python3 python3-base $ovs_pkg");
    }

    # Start openvswitch service
    systemctl('start openvswitch');

    # Create vswitch, virtual tap devices and add them to vswitch
    assert_script_run 'ovs-vsctl --may-exist add-br ovsbr0';
    assert_script_run 'ip tuntap add mode tap vport1';
    assert_script_run 'ip tuntap add mode tap vport2';
    assert_script_run 'ip link set vport1 up';
    assert_script_run 'ip link set vport2 up';
    assert_script_run 'ovs-vsctl --may-exist add-port ovsbr0 vport1';
    assert_script_run 'ovs-vsctl --may-exist add-port ovsbr0 vport2';

    # Prepare private/public keys, and certificates
    for my $pem (qw(ca-cert.pem ca-key.pem server-cert.pem server-key.pem client-cert.pem client-key.pem)) {
        assert_script_run 'wget --quiet ' . data_url("openssl/$pem") . ' -P /etc/openvswitch';
    }

    # Start a dummy SSL server that listens on port 6634 using the server certs
    type_string("openssl s_server -accept 6634 "
          . "-key /etc/openvswitch/server-key.pem "
          . "-cert /etc/openvswitch/server-cert.pem "
          . "-CAfile /etc/openvswitch/ca-cert.pem "
          . "-Verify 1 2>&1 | tee /dev/$serialdev &\n");

    die 'openssl s_server did not start correctly' unless wait_serial(qr/ACCEPT/ms, 15);
    send_key 'ret' for (1 .. 2);    # ensure prompt

    # Set OVS to use SSL and point to the dummy server
    assert_script_run 'ovs-vsctl set-ssl /etc/openvswitch/client-key.pem /etc/openvswitch/client-cert.pem /etc/openvswitch/ca-cert.pem';
    assert_script_run 'ovs-vsctl set-controller ovsbr0 "ssl:127.0.0.1:6634"';

    # Wait and check connection (it will likely connect then quickly drop, but enough to test SSL)
    for (1 .. 3) {
        sleep 10;
        diag "Trying to check connection: $_ of 3";
        enter_cmd "ovs-vsctl show | tee /dev/$serialdev";
        if (wait_serial qr/Controller "ssl:127\.0\.0\.1:6634"/ms) {
            last;
        } else {
            die 'Connection check failed' if ($_ == 3);
        }
    }

    # Kill the openssl server
    assert_script_run "pkill -f 'openssl s_server'";
}

sub test_flags {
    return {fatal => 0};
}

1;
