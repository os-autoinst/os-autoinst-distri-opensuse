# oSUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Setup br0 bridge network for SLES16 virtualization host
# This module creates a bridge interface using NetworkManager for KVM/QEMU guests
# Expected to be executed after agama_reboot for SLES16 virtualization hosts

# Maintainer: QE Virtualization <qe-virt@suse.de>

use base "opensusebasetest";
use testapi;
use strict;
use warnings;
use utils;
use version_utils qw(is_sle);
use Utils::Architectures qw(is_s390x);
use utils qw(zypper_call script_retry);

sub run {
    my ($self) = @_;

    # Only run on SLES16 non-s390x systems for virtualization
    my $host_bridge = "br0";
    my $config_path = "/etc/NetworkManager/system-connections/$host_bridge.nmconnection";

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

    record_info("Bridge Setup", "Creating br0 bridge for SLES16 virtualization host using professional method");

    # Check if bridge configuration already exists
    if (script_run("[[ -f $config_path ]]") == 0) {
        record_info("Bridge config exists", "br0 NetworkManager configuration already exists");
        script_run("ip addr show br0");
        script_run("ip route show");
        return;
    }

    # Step 1: Install required Python packages for NetworkManager DBUS
    record_info("Installing packages", "Installing python313-psutil and python313-dbus-python");
    zypper_call('-t in python313-psutil python313-dbus-python', exitcode => [0, 4, 102, 103, 106]);

    # Step 2: Download bridge creation script from data directory
    my $wait_script = "180";
    my $script_name = "create_host_bridge.py";
    my $script_url = data_url("virt_autotest/$script_name");

    record_info("Downloading script", "Downloading bridge creation script from: $script_url");
    my $download_script = "curl -s -o ~/$script_name $script_url";
    script_output($download_script, $wait_script, type_command => 0, proceed_on_failure => 0);

    # Step 3: Execute the bridge creation script
    record_info("Creating bridge", "Executing Python NetworkManager DBUS script");
    my $execute_script = "chmod +x ~/$script_name && python3 ~/$script_name";
    script_output($execute_script, $wait_script, type_command => 0, proceed_on_failure => 0);

    save_screenshot;

    # Step 4: Re-establish SSH connection after network change
    record_info("Reconnecting", "Re-establishing SSH connection after bridge creation");
    # Wait for NetworkManager to stabilize the bridge interface
    script_retry("nmcli con show br0 | grep 'connection.interface-name.*br0'", delay => 3, retry => 5);
    select_console('root-ssh');

    # Step 5: Configure bridge route priority and activate
    record_info("Configuring bridge", "Setting route metric and activating br0");
    script_run("nmcli con modify br0 ipv4.route-metric 100");
    script_run("nmcli con up br0");

    # Step 6: Verify bridge configuration
    record_info("Bridge verification", "Verifying bridge network configuration");
    script_run("ip r");
    my $bridge_info = script_output("ip a show br0", proceed_on_failure => 1, timeout => 60);
    record_info("Bridge interface", $bridge_info);

    # Test network connectivity
    if (script_run("ping -c 3 8.8.8.8") == 0) {
        record_info("Network test", "Network connectivity verified after bridge setup");
    } else {
        record_soft_failure("Network connectivity test failed after bridge setup");
    }

    # Save final screenshot
    save_screenshot;
}

sub test_flags {
    return {milestone => 1, fatal => 0};
}

1;
