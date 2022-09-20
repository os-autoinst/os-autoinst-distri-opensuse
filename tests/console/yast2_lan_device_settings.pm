# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-network
# Summary: Device setup test for yast2-lan/yast2-network
# - Sets static IP address
# - Sets dynamic IP address
# - Assigns hostname to loopback IP and back
# - Adds VLAN device, assigns dynamic IP address to it, then removes it
#
# Maintainer: Veronika Svecova <vsvecova@suse.com>

use strict;
use base 'y2_module_consoletest';
use warnings;
use testapi;
use Utils::Architectures;
use utils;
use version_utils qw(is_sle is_leap is_tumbleweed);
use y2lan_restart_common;

sub run {
    my $self = shift;
    my $static_ip = "192.168.1.119";
    my $static_hostname = 'testhost';
    my $is_set_in_etc_host = sub { return script_run('grep ' . shift . ' /etc/hosts') == 0 };

    select_console 'root-console';
    zypper_call "in yast2-network";    # make sure yast2 lan module is installed

    # for debugging purposes only
    script_run('ip a');
    script_run('ls -alF /etc/sysconfig/network/');
    save_screenshot;
    unless (is_s390x) {
        my $opened = open_yast2_lan();
        wait_still_screen;
        if ($opened eq "Controlled by network manager") {
            return;
        }

        send_key "alt-i";    # open edit device dialog
        assert_screen 'edit-network-card';
        send_key "alt-t";    # select static IP address option
        send_key "tab";
        type_string $static_ip;
        send_key 'alt-o';
        send_key_until_needlematch 'hostname-localhost-removed', 'backspace';
        type_string $static_hostname;
        send_key "alt-n";    # next
        wait_still_screen;
        assert_screen([qw(yast_lan_duplicate_ip static-ip-address-set)]);
        if (match_has_tag 'yast_lan_duplicate_ip') {
            send_key "alt-n";
            send_key "alt-c";
            close_yast2_lan();
            record_info("Duplicate IP, $static_ip is currently unavailable. Skipping static IP assignment", result => 'softfail');
        } elsif (match_has_tag 'static-ip-address-set') {
            close_yast2_lan();

            # verify that static IP has been set
            assert_script_run "ip a | grep $static_ip";
            # verify that hostname for static ip is recorded in /etc/hosts
            $is_set_in_etc_host->($static_hostname) or die qq{Static hostname "$static_hostname" was not written to /etc/hosts file!\n};

            open_yast2_lan();
            for (1 .. 2) { send_key "tab" }    # move to device list
            send_key "alt-i";    # open edit device dialog
            wait_still_screen;
            assert_screen 'edit-network-card';
            send_key "alt-y";    # select dynamic address option
            send_key "alt-n";    # next
            assert_screen 'dynamic-ip-address-set';
            close_yast2_lan('yast2-ncurses-closed');

            # verify that dynamic IP address has been set
            assert_script_run "ip r s | grep dhcp";
            # verify that static ip is not recorded in /etc/hosts
            if ($is_set_in_etc_host->($static_ip)) {
                record_soft_failure 'bsc#1115644 yast2 lan does not update /etc/hosts after shifting from static ip to dynamic';
                assert_script_run qq{sed -i '/$static_ip/d' /etc/hosts};
                assert_script_run q{cat /etc/hosts};
            }
        }
    }
    # on SLE15-SP1+ / Leap 15.1+ the assign loopback checkbox has been dropped
    if (is_sle('<=15') || is_leap('<=15.0')) {
        open_yast2_lan();

        send_key 'alt-s';    # move to hostname/DNS tab
        send_key_until_needlematch 'loopback-assigned', 'alt-a';    # assign hostname to loopback IP
        close_yast2_lan();

        # verify that loopback has been set
        assert_script_run "cat /etc/hosts | grep 127.0.0.2";

        open_yast2_lan();

        # unassign back from loopback IP
        send_key 'alt-s';
        send_key_until_needlematch 'loopback-unassigned', 'alt-a';
        close_yast2_lan();
    }

    open_yast2_lan();

    send_key "alt-a";    # add another device
    assert_screen [qw(hardware-dialog device-setup-pop-up)];
    if (match_has_tag 'device-setup-pop-up') {
        send_key "alt-o";
        assert_screen 'hardware-dialog';
    }
    send_key "tab";

    # open device type drop down and select vlan
    if (is_tumbleweed || is_leap('15.2+') || is_sle('15-SP2+')) {
        send_key "alt-v";
    }
    else {
        for (1 .. 3) { send_key "down" }
        send_key "ret";
    }

    assert_screen 'add-vlan-selected';
    # next
    send_key "alt-n";
    # YaST2 starts filesystem probing after adding VLAN device
    $self->ncurses_filesystem_probing('edit-network-card');
    send_key "alt-y";    # set dynamic address
    assert_screen 'dynamic-address-selected';
    send_key "alt-n";    # next
    assert_screen 'vlan-added';
    close_yast2_lan();

    # verify that VLAN device has been added
    assert_script_run "ls -l /etc/sysconfig/network/ | grep vlan";

    open_yast2_lan();

    for (1 .. 2) { send_key "tab" }    # move to device list
    send_key_until_needlematch 'vlan-selected', 'down', 6, 5;    # move to vlan
    send_key "alt-t";    # remove vlan
    assert_screen 'vlan-deleted';
    close_yast2_lan();
    wait_still_screen;

    clear_console;
    script_run('ip -o a s');
    script_run('ip r s');
    assert_script_run('getent ahosts ' . get_var("OPENQA_HOSTNAME"));
}

1;
