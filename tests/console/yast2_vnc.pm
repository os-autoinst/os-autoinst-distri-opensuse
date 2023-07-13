# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: vncmanager xorg-x11
# Summary: Configure remote administration with yast2 vnc
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base "y2_module_consoletest";

use testapi;
use utils;
use registration 'add_suseconnect_product';
use yast2_shortcuts qw($is_older_product %remote_admin %firewall_settings %firewall_details $confirm);
use Utils::Backends 'is_pvm';

sub configure_remote_admin {
    # Force ncurses mode on powerVM setup to skip ssh forwarding x11 console
    my %params = (yast2_module => 'remote');
    $params{yast2_opts} = '--ncurses' if (get_var("FIPS_ENABLED") && is_pvm);
    my $module_name = y2_module_consoletest::yast2_console_exec(%params);
    # Remote Administration Settings
    assert_screen 'yast2_vnc_remote_administration';
    send_key $remote_admin{allow_remote_admin_with_session};
    assert_screen 'yast2_vnc_allow_remote_admin_with_session';
    # Firewall Settings
    if (check_screen 'yast2_vnc_firewall_port_closed') {
        send_key $firewall_settings{open_port};
    }
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
    wait_serial("$module_name-0", 60) || die "'yast2 remote' didn't finish";
    # Restart display-manager service to make the changes take effect for powerVM x11 access in FIPs test
    systemctl('restart display-manager') if (get_var("FIPS_ENABLED") && is_pvm);
}

sub check_service_listening {
    my $cmd_check_port = $is_older_product ? 'netstat' : 'ss -tln | grep -E LISTEN.*:5901';
    script_retry("$cmd_check_port", retry => 5, delay => 1);
    systemctl('status vncmanager');
}

sub test_setup {
    select_console 'root-console';
    assert_script_run("if ! systemctl -q is-active network; then systemctl -q start network; fi");
    zypper_call('in vncmanager xorg-x11' . ($is_older_product ? ' net-tools' : ''));
}

sub run {
    test_setup;
    configure_remote_admin;
    check_service_listening;
}

1;
