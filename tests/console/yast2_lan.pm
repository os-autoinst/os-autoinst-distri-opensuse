# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


# Summary: yast2 lan functionality test https://bugzilla.novell.com/show_bug.cgi?id=600576
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base "console_yasttest";
use strict;
use testapi;
use utils;
use version_utils qw(is_sle is_tumbleweed is_leap);

sub handle_Networkmanager_controlled {
    send_key "ret";    # confirm networkmanager popup
    assert_screen "Networkmanager_controlled-approved";
    send_key "alt-c";
    if (check_screen('yast2-lan-really', 3)) {
        # SLED11...
        send_key 'alt-y';
    }
    wait_serial("yast2-lan-status-0", 60) || die "'yast2 lan' didn't finish";
}

sub handle_dhcp_popup {
    if (match_has_tag('dhcp-popup')) {
        wait_screen_change { send_key 'alt-o' };
    }
}

sub open_yast2_lan {
    script_sudo("yast2 lan; echo yast2-lan-status-\$? > /dev/$serialdev", 0);
}

sub close_yast2_lan {
    send_key "alt-o";    # OK=>Save&Exit
    wait_serial("yast2-lan-status-0", 180) || die "'yast2 lan' didn't finish";
    wait_still_screen;
    clear_console;
}

sub run {
    my $self = shift;

    my $hostname  = get_var('HOSTNAME', 'susetest');
    my $domain    = "zq1.de";
    my $static_ip = "192.168.1.119";

    select_console 'user-console';
    assert_script_sudo "zypper -n in yast2-network";    # make sure yast2 lan module installed

    # those two are for debugging purposes only
    script_run('ip a');
    script_run('ls -alF /etc/sysconfig/network/');
    save_screenshot;

    script_sudo("yast2 lan; echo yast2-lan-status-\$? > /dev/$serialdev", 0);

    assert_screen [qw(Networkmanager_controlled yast2_lan install-susefirewall2 install-firewalld dhcp-popup)], 120;
    handle_dhcp_popup;
    if (match_has_tag('Networkmanager_controlled')) {
        handle_Networkmanager_controlled;
        return;    # don't change any settings
    }
    if (match_has_tag('install-susefirewall2') || match_has_tag('install-firewalld')) {
        # install firewall
        send_key "alt-i";
        # check yast2_lan again after firewall is installed
        assert_screen [qw(Networkmanager_controlled yast2_lan)], 90;
        if (match_has_tag('Networkmanager_controlled')) {
            handle_Networkmanager_controlled;
            return;
        }
    }

    send_key "alt-s";    # open hostname tab
    assert_screen [qw(yast2_lan-hostname-tab dhcp-popup)];
    handle_dhcp_popup;
    send_key "tab";
    for (1 .. 15) { send_key "backspace" }
    type_string $hostname;
    # on SLE15-SP1+ and Leap 15.1+ the domain field is dropped
    if (is_sle('<=15') || is_leap('<=15.0')) {
        send_key "tab";
        for (1 .. 15) { send_key "backspace" }
        type_string $domain;
    }
    assert_screen 'test-yast2_lan-1';
    close_yast2_lan;

    # verify that hostname has been changed
    assert_script_run "hostname | grep $hostname";

    open_yast2_lan;
    assert_screen [qw(yast2_lan dhcp-popup)], 90;
    handle_dhcp_popup;

    send_key "alt-i";    # open edit device dialog
    assert_screen 'edit-network-card';
    send_key "alt-t";    # select static IP address option
    send_key "tab";
    type_string $static_ip;
    send_key "alt-n";    # next
    assert_screen 'static-ip-address-set';
    close_yast2_lan;

    # verify that static IP has been set
    assert_script_run "ip a | grep $static_ip";

    open_yast2_lan;
    assert_screen [qw(yast2_lan dhcp-popup)], 90;
    handle_dhcp_popup;

    send_key "alt-i";    # open edit device dialog
    assert_screen 'edit-network-card';
    send_key "alt-y";    # select dynamic address option
    send_key "alt-n";    # next
    assert_screen 'dynamic-ip-address-set';
    close_yast2_lan;

    # verify that dynamic IP address has been set
    assert_script_run "ip r s | grep dhcp";

    # on SLE15-SP1+ / Leap 15.1+ the assign loopback checkbox has been dropped
    if (is_sle('<=15') || is_leap('<= 15.0')) {
        open_yast2_lan;
        assert_screen [qw(yast2_lan dhcp_popup)], 90;
        handle_dhcp_popup;

        send_key "alt-s";    # move to hostname/DNS tab
        send_key "alt-a";    # assign hostname to loopback IP
        assert_screen 'loopback-assigned';
        close_yast2_lan;

        # verify that loopback has been set
        assert_script_run "cat /etc/hosts | grep 127.0.0.2";

        open_yast2_lan;
        assert_screen [qw(yast2_lan dhcp-popup)], 90;
        handle_dhcp_popup;

        # unassign back from loopback IP
        send_key "alt-s";
        send_key "alt-a";
        assert_screen 'loopback-unassigned';
        close_yast2_lan;
    }

    open_yast2_lan;
    assert_screen [qw(yast2_lan dhcp-popup)], 90;
    handle_dhcp_popup;

    send_key "alt-a";    # add another device
    send_key "tab";
    for (1 .. 3) { send_key "down" }    # open device type drop down and select vlan
    send_key "ret";
    assert_screen 'add-vlan-selected';
    send_key "alt-n";                   # next
    assert_screen 'edit-network-card';
    send_key "alt-y";                   # set dynamic address
    assert_screen 'dynamic-address-selected';
    send_key "alt-n";                   # next
    assert_screen 'vlan-added';
    close_yast2_lan;

    # verify that VLAN device has been added
    assert_script_run "ls -l /etc/sysconfig/network/ | grep vlan";

    open_yast2_lan;
    assert_screen [qw(yast2_lan dhcp-popup)], 90;
    handle_dhcp_popup;

    for (1 .. 2) { send_key "tab" }     # move to device list
    send_key "down";                    # move to vlan
    assert_screen 'vlan-selected';
    send_key "alt-t";                   # remove vlan
    assert_screen 'vlan-deleted';
    close_yast2_lan;
    wait_still_screen;

    # check that correct module comes up as well when yast2 network is run
    script_sudo("yast2 network; echo yast2-network-status-\$? > /dev/$serialdev", 0);
    assert_screen 'yast2-network';
    send_key "alt-l";                   # launch available network module
    assert_screen [qw(yast2_lan dhcp-popup)], 90;
    handle_dhcp_popup;
    send_key "alt-o";                   # OK=>Save&Exit
    wait_serial("yast2-network-status-0", 180) || die "'yast2 network' didn't finish";

    clear_console;
    script_run('ip -o a s');
    script_run('ip r s');
    assert_script_run('getent ahosts ' . get_var("OPENQA_HOSTNAME"));
}

1;

