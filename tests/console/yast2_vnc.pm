# SUSE's openQA tests
#
# Copyright (c) 2016-2018 SUSE LLC
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
use version_utils qw(is_leap is_sle);


sub run {
    my $self = shift;
    select_console 'root-console';

    # check network at first
    assert_script_run("if ! systemctl -q is-active network; then systemctl -q start network; fi");

    # install components to test plus dependencies for checking
    my $packages = 'vncmanager xorg-x11';
    # netstat is deprecated in newer versions, use 'ss' instead
    my $use_nettools = is_sle('<15') || is_leap('<15.0');
    $packages .= ' net-tools' if $use_nettools;
    zypper_call("in $packages");

    # start Remote Administration configuration
    script_run("yast2 remote; echo yast2-remote-status-\$? > /dev/$serialdev", 0);

    # check Remote Administration VNC got started
    assert_screen 'yast2_vnc_remote_administration';
    # enable remote administration
    send_key 'alt-a';
    if (is_sle('<15') || is_leap('<15.0')) {
        # open port in firewall if it is eanbaled and check network interfaces, check long text by send key right.
        if (check_screen 'yast2_vnc_open_port_firewall', 30) {
            send_key 'alt-p';
            send_key 'alt-d';
            assert_screen 'yast2_vnc_firewall_port_details';
            send_key 'alt-e';
            for (1 .. 5) { send_key 'right'; }
            send_key 'alt-a';
            send_key 'alt-o';
        }
        send_key 'alt-o';    # ok
    }
    else {
        assert_screen 'yast2_vnc_firewall_port_closed';
        send_key 'alt-f';    # Open port
        assert_screen 'yast2_vnc_firewall_port_open';
        send_key 'alt-n';    # next
    }
    # confirm with OK for Warning dialogue
    assert_screen 'yast2_vnc_warning_text';
    send_key 'alt-o';
    wait_serial('yast2-remote-status-0', 60) || die "'yast2 remote' didn't finish";

    # Check service listening
    my $cmd_check_port = $use_nettools ? 'netstat' : 'ss' . ' -tln | grep -E LISTEN.*:5901';
    if (script_run($cmd_check_port)) {
        record_soft_failure 'boo#1088646 - service vncmanager is not started automatically';
        systemctl('status vncmanager', expect_false => 1);
        systemctl('restart vncmanager');
        systemctl('status vncmanager');
        assert_script_run $cmd_check_port;
    }
    # Check firewall open for vnc
    if ($self->firewall eq 'firewalld') {
        my $cmd_check_firewall = 'firewall-cmd --list-services | grep \'tigervnc tigervnc-https\'';
        if (script_run($cmd_check_firewall)) {
            record_soft_failure 'boo#1088647 - firewalld does not create rule for vnc';
            assert_script_run('firewall-cmd --zone=public --add-service=tigervnc --permanent');
            assert_script_run('firewall-cmd --zone=public --add-service=tigervnc-https --permanent');
            assert_script_run('firewall-cmd --reload');
            assert_script_run($cmd_check_firewall);
        }
    }
}
1;
