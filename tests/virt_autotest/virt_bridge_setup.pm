# SUSE's openQA tests
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: test virt-bridge-setup tool on sle16.1+
# Maintainer: qe-virt@suse.de, Julie CAO <JCao@suse.com>

package virt_bridge_setup;
use base "virt_autotest_base";
use testapi;
use version_utils qw(is_sle);
use Utils::Architectures;
use Utils::Backends 'use_ssh_serial_console';
use virt_autotest::utils qw(setup_br0_with_virt_bridge_setup check_host_health);

sub run {

    select_console 'sol', await_console => 0;
    use_ssh_serial_console;

    # Record the initial network status
    record_info("virt-bridge-setup", script_output("rpm -q virt-bridge-setup", proceed_on_failure => 1));
    record_info("Usage", script_output("virt-bridge-setup --help"));
    record_info("Network status", script_output("nmcli con") . "\n\n" . script_output("ip a"));
    record_info("NM configuration files", script_output("ls -l /etc/NetworkManager/system-connections"));

    # Setup br0 with virt-bridge-setup tool
    setup_br0_with_virt_bridge_setup if is_sle('16.1+') and !is_s390x;
    test_br0_created;

    check_host_health;
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
    record_info("br0 creation tested", "");
}

sub test_flags {
    #continue subsequent test in the case test restored
    return {fatal => 1};
}

1;
