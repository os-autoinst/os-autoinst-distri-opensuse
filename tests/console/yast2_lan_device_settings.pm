# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Device setup test for yast2-lan/yast2-network
# - Sets static IP address
# - Sets dynamic IP address
# - Assigns hostname to loopback IP and back
# - Adds VLAN device, assigns dynamic IP address to it, then removes it
#
# Maintainer: Veronika Svecova <vsvecova@suse.com>

use base "y2_module_consoletest";
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_sle is_leap is_tumbleweed);
use y2lan_restart_common;

sub run {
    my $self      = shift;
    my $static_ip = "192.168.1.119";

    select_console 'root-console';
    assert_script_run "zypper -n in yast2-network";    # make sure yast2 lan module is installed

    # for debugging purposes only
    script_run('ip a');
    script_run('ls -alF /etc/sysconfig/network/');
    save_screenshot;

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
    send_key "alt-n";    # next
    assert_screen 'static-ip-address-set';
    close_yast2_lan();

    # verify that static IP has been set
    assert_script_run "ip a | grep $static_ip";

    open_yast2_lan();
    for (1 .. 2) { send_key "tab" }    # move to device list
    send_key "alt-i";                  # open edit device dialog
    wait_still_screen;
    assert_screen 'edit-network-card';
    send_key "alt-y";                  # select dynamic address option
    send_key "alt-n";                  # next
    assert_screen 'dynamic-ip-address-set';
    close_yast2_lan();

    # verify that dynamic IP address has been set
    assert_script_run "ip r s | grep dhcp";

    # on SLE15-SP1+ / Leap 15.1+ the assign loopback checkbox has been dropped
    if (is_sle('<=15') || is_leap('<=15.0')) {
        open_yast2_lan();

        send_key "alt-s";              # move to hostname/DNS tab
        send_key "alt-a";              # assign hostname to loopback IP
        assert_screen 'loopback-assigned';
        close_yast2_lan();

        # verify that loopback has been set
        assert_script_run "cat /etc/hosts | grep 127.0.0.2";

        open_yast2_lan();

        # unassign back from loopback IP
        send_key "alt-s";
        send_key "alt-a";
        assert_screen 'loopback-unassigned';
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
    if (is_tumbleweed || is_leap('15.2+')) {
        send_key "alt-v";
    }
    else {
        for (1 .. 3) { send_key "down" }
        send_key "ret";
    }

    assert_screen 'add-vlan-selected';
    send_key "alt-n";    # next
    assert_screen 'edit-network-card';
    send_key "alt-y";    # set dynamic address
    assert_screen 'dynamic-address-selected';
    send_key "alt-n";    # next
    assert_screen 'vlan-added';
    close_yast2_lan();

    # verify that VLAN device has been added
    assert_script_run "ls -l /etc/sysconfig/network/ | grep vlan";

    open_yast2_lan();

    for (1 .. 2) { send_key "tab" }    # move to device list
    send_key "down";                   # move to vlan
    assert_screen 'vlan-selected';
    send_key "alt-t";                  # remove vlan
    assert_screen 'vlan-deleted';
    close_yast2_lan();
    wait_still_screen;

    clear_console;
    script_run('ip -o a s');
    script_run('ip r s');
    assert_script_run('getent ahosts ' . get_var("OPENQA_HOSTNAME"));
}

1;
