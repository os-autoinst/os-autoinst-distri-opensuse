# SUSE's openQA tests
#
# Copyright 2016-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2
# Summary: YaST logic on Network Restart while no config changes were made
# - Launch xterm as root, stop firewalld
# - Put network in debug mode (DEBUG="yes" on /etc/sysconfig/network/config)
# - Launch yast2 lan
# - Add a device type brigde (dhcp)
# - Add a device type bond
# - Add a device type vlan
# - Select the device
# - Check the network status for each device (if network was restarted after
# changes made)
# - Delete all created devices
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>
# Tags: fate#318787 poo#11450

use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use y2lan_restart_common qw(initialize_y2lan open_network_settings close_network_settings check_network_status);
use version_utils 'is_sle';
use Utils::Architectures;

sub check_bsc1111483 {
    return 0 unless match_has_tag('yast2_lan_device_bsc1111483');
    record_soft_failure 'bsc#1111483 - default VLAN name changed';
    close_network_settings;
    return 1;
}

sub add_device {
    my $device = shift;

    assert_screen 'yast2_closed_xterm_visible', 120;
    open_network_settings;
    if ($device eq 'bond') {
        wait_screen_change { send_key 'home' };
        send_key_until_needlematch 'yast2_lan_select_eth_card', 'down';
        send_key 'alt-i';    # Edit NIC
        assert_screen 'yast2_lan_network_card_setup';
        send_key 'alt-k';    # No link (Bonding Slavees)
        send_key 'alt-n';
        assert_screen 'yast2_lan';    # yast2 lan overview tab
    }
    send_key 'alt-a';    # Add NIC
    assert_screen 'yast2_lan_hardware_dialog';
    send_key 'alt-d';    # Device type
    send_key 'home';    # Jump to beginning of list
    send_key_until_needlematch "yast2_lan_device_type_$device", 'down';
    send_key 'alt-n';    # Next
    assert_screen 'yast2_lan_network_card_setup';
    send_key 'alt-y';    # Dynamic address
    wait_still_screen;
    if ($device eq 'bridge') {
        send_key 'alt-g';    # General
        send_key 'alt-i';    # Bridged devices
        assert_screen 'yast2_lan_bridged_devices';
        if (check_screen('yast2_lan_default_NIC_bridge', 0)) {
            send_key 'alt-d';    # select Bridged Devices region
            send_key 'spc';
            wait_still_screen;
            save_screenshot;
        }
        send_key 'alt-n';
        assert_screen 'yast2_lan_select_already_configured_device';
        send_key 'alt-o';
    }
    elsif ($device eq 'bond') {
        send_key 'alt-o';    # Bond slaves
        assert_screen 'yast2_lan_bond_slaves';
        send_key_until_needlematch 'yast2_lan_bond_slave_tab_selected', 'tab';
        assert_and_click 'yast2_lan_bond_slave_network_interface';    # select network interface
        send_key 'spc';    # check network interface
        wait_still_screen;
        save_screenshot;
        send_key 'alt-n';
    }
    elsif ($device eq 'VLAN') {
        send_key 'alt-v';
        send_key 'tab';
        wait_screen_change { type_string '12' };
        send_key 'alt-n';
    }
    else {
        send_key 'alt-n';
    }
    close_network_settings;
    assert_script_run '> journal.log';    # clear journal.log
}

sub select_special_device_tab {
    my $device = shift;

    open_network_settings;
    send_key 'tab';
    send_key 'tab';
    send_key 'home';
    send_key_until_needlematch ["yast2_lan_device_${device}_selected", "yast2_lan_device_bsc1111483"], 'down', 6;
    return if check_bsc1111483;
    send_key 'alt-i';    # Edit NIC
    assert_screen 'yast2_lan_network_card_setup';
    if ($device eq 'bridge') {
        send_key 'alt-g';    # General
        send_key 'alt-i';    # Bridged devices
        assert_screen 'yast2_lan_bridged_devices';
    }
    elsif ($device eq 'bond') {
        send_key 'alt-o';    # Bond slaves
        assert_screen 'yast2_lan_bond_slaves';
    }
    elsif ($device eq 'VLAN') {
        assert_screen 'yast2_lan_VLAN';
    }
    wait_still_screen;
    send_key 'alt-n';
    assert_screen 'yast2_lan';
    send_key $cmd{ok};
}

sub delete_device {
    my $device = shift;

    open_network_settings;
    send_key 'tab';
    send_key 'tab';
    send_key 'home';
    send_key_until_needlematch ["yast2_lan_device_${device}_selected", "yast2_lan_device_bsc1111483"], 'down', 6;
    return if check_bsc1111483;
    send_key 'alt-t';    # Delete NIC
    wait_still_screen;
    save_screenshot;
    send_key 'alt-i';    # Edit NIC
    assert_screen 'yast2_lan_network_card_setup';
    wait_screen_change { send_key 'alt-y' };    # Dynamic address
    send_key 'alt-n';    # Next
    close_network_settings;
    assert_script_run '> journal.log';    # clear journal.log
}

sub check_device {
    my $device = shift;

    add_device($device);
    select_special_device_tab($device);
    check_network_status('no_restart_or_reload', $device);
    delete_device($device);
}

sub run {
    initialize_y2lan;
    my @devices = qw(bridge VLAN);
    if (is_sle('<=12-SP5') && is_s390x()) {
        record_soft_failure 'bsc#1145943';
    } else {
        push @devices, 'bond';
    }

    check_device($_) foreach @devices;
    enter_cmd "killall xterm";
}

sub post_fail_hook {
    my ($self) = @_;
    assert_script_run 'journalctl -b -o short-precise > /tmp/journal', 90;
    upload_logs '/tmp/journal';
    $self->SUPER::post_fail_hook;
}

1;
