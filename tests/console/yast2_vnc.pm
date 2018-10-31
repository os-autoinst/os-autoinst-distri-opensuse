# SUSE's openQA tests
#
# Copyright (c) 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Configure remote administration with yast2 vnc
# Maintainer: Joaquín Rivera <jeriveramoya@suse.com>

use strict;
use base "console_yasttest";
use testapi;
use utils;
use registration 'add_suseconnect_product';
use yast2_shortcuts qw($is_older_product %remote_admin %firewall_settings %firewall_details $confirm);

sub configure_remote_admin {
    # Remote Administration Settings
    assert_screen 'yast2_vnc_remote_administration';
    return if check_var('ARCH', 's390x');
    send_key $remote_admin{allow_remote_admin_with_session};
    assert_screen 'yast2_vnc_allow_remote_admin_with_session';
    # Firewall Settings
    assert_screen 'yast2_vnc_firewall_port_closed';
    send_key $firewall_settings{open_port};
    # Firewall Details
    assert_screen 'yast2_vnc_firewall_port_open';
    send_key $firewall_settings{details};
    assert_screen 'yast2_vnc_firewall_port_details';
    send_key $firewall_details{network_interfaces};
    assert_screen 'yast2_vnc_firewall_details_interface_selected';
    send_key $cmd{ok};
    assert_screen 'yast2_vnc_firewall_details_selected';
    # Confirm configuration
    send_key $confirm;
    assert_screen 'yast2_vnc_warning_text';
    send_key $cmd{ok};
    wait_serial('yast2-remote-status-0', 60) || die "'yast2 remote' didn't finish";
}

sub check_service_listening {
    my $cmd_check_port = $is_older_product ? 'netstat' : 'ss -tln | grep -E LISTEN.*:5901';
    if (script_run($cmd_check_port)) {
        record_soft_failure 'boo#1088646 - service vncmanager is not started automatically';
        systemctl('status vncmanager', expect_false => 1);
        systemctl('restart vncmanager');
        systemctl('status vncmanager');
        assert_script_run $cmd_check_port;
    }
}

sub test_setup {
    select_console 'root-console';
    assert_script_run("if ! systemctl -q is-active network; then systemctl -q start network; fi");
    if (check_var('ARCH', 's390x') && !$is_older_product) {
        add_suseconnect_product('sle-module-desktop-applications', undef, undef, undef, 180);
    }
    zypper_call('in vncmanager xorg-x11' . ($is_older_product ? ' net-tools' : ''));
    script_run("yast2 remote; echo yast2-remote-status-\$? > /dev/$serialdev", 0);
}

sub run {
    test_setup;
    configure_remote_admin;
    return if check_var('ARCH', 's390x');    # exit here as port is already open for s390x
    check_service_listening;
}

1;
