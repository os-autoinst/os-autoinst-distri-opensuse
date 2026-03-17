# SUSE's openQA tests
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: test virt-bridge-setup tool on sle16.1+
# Maintainer: qe-virt@suse.de, Julie CAO <JCao@suse.com>

package virt_bridge_setup;
use base "virt_autotest_base";
use testapi;
use Utils::Backends 'use_ssh_serial_console';

sub run {

    select_console 'sol', await_console => 0;
    use_ssh_serial_console;
    record_info("virt-bridge-setup", script_output("rpm -q virt-bridge-setup"));
    record_info("Usage", script_output("virt-bridge-setup --help"));
    test_br0_created if get_var('SETUP_BR0_WITH_VIRT_BRIDGE_SETUP_TOOL');
}

sub test_br0_created {
    record_info("nmcli", script_output("nmcli con", proceed_on_failure => 1));
    script_run("cat /etc/NetworkManager/system-connections/c-mybr0.nmconnection");
    script_run("cat /etc/NetworkManager/system-connections/c-mybr0-port-*.nmconnection");
    script_run("nmcli con show c-mybr0 | grep stp");
    script_run("ip -d l show mybr0 | grep stp");
    assert_script_run("ip addr show br0");
    assert_script_run("bridge link show br0");
    assert_script_run("nmcli device status | grep br0");
    script_run("nmcli con");
}

sub test_flags {
    #continue subsequent test in the case test restored
    return {fatal => 1};
}

1;
