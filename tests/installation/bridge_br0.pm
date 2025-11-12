# oSUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Setup and verify br0 bridge network for SLES16 virtualization host
# This module calls create_host_bridge_nm() to create a bridge interface using NetworkManager
# for KVM/QEMU guests, then performs additional verification and connectivity testing.
# Expected to be executed after agama_reboot for SLES16 virtualization hosts.

# Maintainer: QE Virtualization <qe-virt@suse.de>

use base "opensusebasetest";
use testapi;
use utils;
use version_utils qw(is_sle);
use Utils::Architectures qw(is_s390x);
use utils qw(zypper_call script_retry);
use virt_autotest::virtual_network_utils;

sub run {
    my ($self) = @_;

    # Only run on SLES16 non-s390x systems for virtualization
    unless (is_sle('=16') && !is_s390x) {
        record_info("Skip bridge setup", "Bridge setup only required for SLES16 non-s390x virtualization hosts");
        return;
    }

    # Check if this is a virtualization test
    unless (get_var('HOST_HYPERVISOR') =~ /kvm|qemu/) {
        record_info("Skip bridge setup", "Not a virtualization test, bridge not needed");
        return;
    }

    # Ensure we're on the installed system
    select_console 'root-console';

    record_info("Bridge Setup", "Creating br0 bridge for SLES16 virtualization host using create_host_bridge_nm");

    # Check if bridge configuration already exists (quick check before calling function)
    my $host_bridge = "br0";
    my $config_path = "/etc/NetworkManager/system-connections/$host_bridge.nmconnection";
    if (script_run("[[ -f $config_path ]]") == 0) {
        record_info("Bridge config exists", "br0 NetworkManager configuration already exists");
        script_run("ip addr show br0");
        script_run("ip route show");
        # Still run verification steps below
    } else {
        # Call the shared bridge creation function
        record_info("Creating bridge", "Calling create_host_bridge_nm function");
        virt_autotest::virtual_network_utils::create_host_bridge_nm();
    }

    # Additional verification and testing (beyond what create_host_bridge_nm provides)
    record_info("Bridge verification", "Verifying bridge network configuration");
    script_run("ip r");
    my $bridge_info = script_output("ip a show br0", proceed_on_failure => 1, timeout => 60);
    record_info("Bridge interface", $bridge_info);

    # Test network connectivity
    if (script_run("ping -c 3 8.8.8.8") == 0) {
        record_info("Network test", "Network connectivity verified after bridge setup");
    } else {
        record_info("Network test", "Network connectivity test failed after bridge setup", result => 'fail');
    }

    # Save final screenshot
    save_screenshot;
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
