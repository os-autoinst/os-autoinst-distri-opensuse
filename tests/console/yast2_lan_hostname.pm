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
use y2_common 'accept_warning_network_manager_default';

sub hostname_via_dhcp {
    my $dhcp = shift;

    # keyboard shortcuts
    $cmd{hostname_dns_tab} = 'alt-s';
    $cmd{home}             = 'home';
    $cmd{spc}              = 'spc';

    type_string "yast2 lan\n";
    accept_warning_network_manager_default;
    assert_screen 'yast2_lan';
    # Hostname/DNS tab
    send_key $cmd{hostname_dns_tab};
    assert_screen "yast2_lan-hostname-tab";
    for (1 .. 4) { send_key 'tab' }    # go to roll-down list
    wait_screen_change { send_key 'down'; };    # open roll-down list
    send_key $cmd{home};
    assert_screen("yast2_lan-hostname-DHCP-no");    # check that topmost option is selected
    send_key_until_needlematch "yast2_lan-hostname-DHCP-$dhcp", 'down';
    wait_screen_change { send_key $cmd{spc}; };
    assert_screen "yast2_lan-hostname-DHCP-$dhcp-selected";    # make sure that the option is actually selected
    send_key $cmd{ok};
    assert_screen 'console-visible';                           # yast module exited
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
        assert_script_run 'grep DHCLIENT_SET_HOSTNAME /etc/sysconfig/network/dhcp|grep yes';
    }
}

sub run {
    select_console 'root-console';
    assert_script_run 'zypper -n in yast2-network';    # make sure yast2 lan module installed
    hostname_via_dhcp('no');
    hostname_via_dhcp('yes-any');
    hostname_via_dhcp('yes-eth0');
}

sub post_fail_hook {
    assert_script_run 'iface=`ip -o addr show scope global | head -n1 | cut -d" " -f2`';
    upload_logs '/etc/sysconfig/network/ifcfg-$iface';
    upload_logs '/etc/sysconfig/network/dhcp';
}

1;
