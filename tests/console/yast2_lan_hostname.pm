# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


# Summary: yast2 lan hostname via DHCP test https://bugzilla.suse.com/show_bug.cgi?id=984890
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base "console_yasttest";
use strict;
use testapi;
use utils;

sub hostname_via_dhcp {
    my $dhcp = shift;

    type_string "yast2 lan\n";
    assert_screen([qw(yast2_lan yast2_still_susefirewall2)], 90);
    if (match_has_tag 'yast2_still_susefirewall2') {
        record_soft_failure "bsc#1059569";
        send_key 'alt-i';
        assert_screen 'yast2_lan';
    }

    send_key "alt-s";    # open hostname tab
    assert_screen "yast2_lan-hostname-tab";
    for (1 .. 4) { send_key 'tab' }    # go to roll-down list
    wait_screen_change { send_key 'down'; };    # open roll-down list
    for (1 .. 3) { send_key 'up' }              # go on top of list
    send_key_until_needlematch "yast2_lan-hostname-DHCP-$dhcp", 'down';
    wait_screen_change { send_key 'spc'; };     # pick selected option
    send_key 'alt-o';                           # OK=>Save&Exit
    assert_screen 'console-visible';            # yast module exited
    wait_still_screen;
    if ($dhcp eq 'no') {
        assert_script_run 'grep DHCLIENT_SET_HOSTNAME /etc/sysconfig/network/dhcp|grep no';
    }
    elsif ($dhcp eq 'yes-eth0') {
        assert_script_run 'iface=`ip -o addr show scope global | head -n1 | cut -d" " -f2`';
        assert_script_run 'grep DHCLIENT_SET_HOSTNAME /etc/sysconfig/network/ifcfg-$iface|grep yes';
        assert_script_run 'grep DHCLIENT_SET_HOSTNAME /etc/sysconfig/network/dhcp|grep no';
    }
    elsif ($dhcp eq 'yes-any') {
        # sometimes settings not yep
        sleep 60;
        assert_script_run 'grep DHCLIENT_SET_HOSTNAME /etc/sysconfig/network/dhcp|grep yes';
    }
}

sub run {
    select_console 'root-console';
    assert_script_run 'zypper -n in yast2-network';    # make sure yast2 lan module installed
    hostname_via_dhcp('no');
    hostname_via_dhcp('yes-eth0');
    hostname_via_dhcp('yes-any');
}

sub post_fail_hook {
    assert_script_run 'iface=`ip -o addr show scope global | head -n1 | cut -d" " -f2`';
    upload_logs '/etc/sysconfig/network/ifcfg-$iface';
    upload_logs '/etc/sysconfig/network/dhcp';
}

1;

# vim: set sw=4 et:
