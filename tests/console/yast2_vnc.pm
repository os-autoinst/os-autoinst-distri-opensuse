# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Add test for yast2 vnc
# Maintainer: Zaoliang Luo <zluo@suse.de>

use strict;
use base "console_yasttest";
use testapi;
use utils;


sub run {
    select_console 'root-console';

    # check network at first
    assert_script_run("if ! systemctl -q is-active network; then systemctl -q start network; fi");

    # install components to test plus dependencies for checking
    my $packages = 'vncmanager xorg-x11';
    # netstat is deprecated in newer versions, use 'ss' instead
    my $use_nettools = (is_sle && !sle_version_at_least('15')) || (is_leap && !leap_version_at_least('15'));
    $packages .= ' net-tools' if $use_nettools;
    zypper_call("in $packages");

    # start Remote Administration configuration
    script_run("yast2 remote; echo yast2-remote-status-\$? > /dev/$serialdev", 0);

    # check Remote Administration VNC got started
    assert_screen([qw(yast2_vnc_remote_administration yast2_still_susefirewall2)], 90);
    if (match_has_tag 'yast2_still_susefirewall2') {
        record_soft_failure "bsc#1059569";
        send_key 'alt-i';
        assert_screen 'yast2_vnc_remote_administration';
    }

    # enable remote administration
    send_key 'alt-a';
    wait_still_screen;

    # open port in firewall if it is eanbaled and check network interfaces, check long text by send key right.
    if (check_screen 'yast2_vnc_open_port_firewall') {
        send_key 'alt-p';
        send_key 'alt-d';
        assert_screen 'yast2_vnc_firewall_port_details';
        send_key 'alt-e';
        for (1 .. 5) { send_key 'right'; }
        send_key 'alt-a';
        send_key 'alt-o';
    }

    # finish configuration with OK
    send_key 'alt-o';
    wait_still_screen;

    # confirm with OK for Warning dialogue
    assert_screen 'yast2_vnc_warning_text';
    send_key 'alt-o';

    wait_serial('yast2-remote-status-0', 60) || die "'yast2 remote' didn't finish";

    # check vnc port is listening
    assert_script_run $use_nettools ? 'netstat' : 'ss' . ' -tl | grep 5901 | grep LISTEN';
}
1;

# vim: set sw=4 et:
