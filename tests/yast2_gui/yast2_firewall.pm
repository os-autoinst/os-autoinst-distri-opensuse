# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-firewall yast2-http-server apache2 apache2-prefork firewalld
# Summary: YaST2 Firewall UI test checks verious configurations and settings of firewall
# Make sure yast2 firewall can opened properly. Configurations can be changed and written correctly.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "y2_module_guitest";
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_sle is_leap is_tumbleweed);
use yast2_shortcuts '%fw';
use network_utils 'iface';
use yast2_widget_utils 'change_service_configuration';

sub susefirewall2 {
    # 	enter page interfaces and change zone for network interface
    assert_and_click("yast2_firewall_config_list");
    assert_screen "yast2_firewall_interfaces";
    assert_and_click("yast2_firewall_interface_zone_change");
    wait_still_screen(2);
    assert_and_click("yast2_firewall_interface_no-zone_assigned");
    wait_still_screen 1;
    wait_screen_change {
        send_key "down";
        send_key "ret";
    };
    wait_still_screen 1;
    send_key "alt-o";
    assert_screen "yast2_firewall_interfaces";

    # 	enter page Allowed Services and make  some changes
    assert_and_click("yast2_firewall_allowed-services");
    assert_and_click("yast2_firewall_service-to-allow");
    assert_and_click("yast2_firewall_service_http");
    send_key "alt-a";
    assert_screen "yast2_firewall_service_http_addded";

    #	enter page Broadcast and disable logging broadcast packets
    assert_and_click("yast2_firewall_broadcast");
    wait_still_screen 1;
    wait_screen_change { send_key "alt-l"; };
    send_key "alt-o";
    assert_screen "yast2_firewall_broadcast_no-logging";

    # 	enter page Logging Level and disable logging
    assert_and_click("yast2_firewall_logging-level");
    assert_and_click("yast2_firewall_do-not-log-any_accepted");
    assert_and_click("yast2_firewall_do-not-log-any_not-accepted");

    #	enter page Custom Rules and check ui
    assert_and_click("yast2_firewall_custom-rules");
    # verify Custom Rules page is displayed
    assert_screen("yast2_firewall_custom-rules-loaded");
    send_key "alt-a";
    assert_screen "yast2_firewall_add-new-allowing-rules";
    send_key "alt-c";
    wait_still_screen(2);

    #	Next to finish and exit
    send_key "alt-n";
    assert_screen "yast2_firewall_summary", 30;
    send_key "alt-f";
}

sub verify_service_stopped {

    record_info('Start-Up', "Managing the firewalld service: Stop");
    select_console 'x11', await_console => 0;
    y2_module_guitest::launch_yast2_module_x11('firewall', target_match => 'firewall-start-page');
    assert_screen 'yast2_firewall_start-up';
    change_service_configuration(after_writing => {stop => 'alt-t'});
    wait_screen_change { send_key $cmd{accept} };
    assert_screen 'generic-desktop';

    select_console 'root-console';
    assert_script_run("! (firewall-cmd --state) | grep 'not running'");
}

sub verify_service_started {

    record_info('Start-Up', "Managing the firewalld service: Start");
    select_console 'x11', await_console => 0;
    y2_module_guitest::launch_yast2_module_x11('firewall', target_match => 'firewall-start-page');
    assert_screen 'yast2_firewall_start-up';
    change_service_configuration(after_writing => {start => 'alt-t'});
    wait_screen_change { send_key $cmd{accept} };
    assert_screen 'generic-desktop';

    select_console 'root-console';
    assert_script_run "firewall-cmd --state | grep running";
}

sub verify_interface {
    my (%args) = @_;

    assert_and_click 'yast2_firewall_interfaces_menu';
    assert_screen 'yast2_firewall_interfaces_' . $args{device} . '_' . $args{zone};
}

sub change_interface_zone {
    my $zone = shift;

    assert_and_click 'yast2_firewall_interfaces_menu';
    assert_screen 'yast2_firewall_interfaces';
    send_key $fw{interfaces_change_zone};
    assert_screen 'yast2_firewall_interfaces_change_zone';
    send_key $fw{interfaces_change_zone_zone};
    enter_cmd "$zone";
}

sub verify_zone {
    my (%args) = @_;

    my $interfaces = $args{interfaces} //= 'no_interfaces';
    my $default = $args{default} //= 'no_default';
    my $menu_selected = $args{menu_selected} //= 0;

    assert_and_click 'yast2_firewall_zones' unless $menu_selected;
    assert_screen 'yast2_firewall_' . $args{name} . '_' . $interfaces . '_' . $default;
}

sub set_default_zone {
    my $zone = shift;

    assert_and_click 'yast2_firewall_zone_' . $zone;
    send_key $fw{zones_set_as_default};
}

sub configure_zone {
    my (%args) = @_;

    assert_and_click 'yast2_firewall_zones';
    if ($args{service}) {
        assert_and_click 'yast2_firewall_zone_' . $args{zone} . '_menu';
        assert_and_click 'yast2_firewall_zone_service_known_scroll_on_top';    # assuming allowed list empty
        send_key_until_needlematch 'yast2_firewall_zone_service_' . $args{service} . '_selected', 'down';
        send_key $fw{zones_service_add};
        assert_screen 'yast2_firewall_zone_service_' . $args{service} . '_allowed';
    }
    if ($args{port}) {
        send_key $fw{zones_ports};
        assert_screen 'yast2_firewall_zone_ports_tab_selected';
        send_key $fw{tcp};
        type_string '7777';
    }
}

sub configure_firewalld {

    record_info('Interface/Zones ', "Verify zone info changing default zone when interface assigned to default zone");
    my $iface = iface;

    select_console 'x11', await_console => 0;
    y2_module_guitest::launch_yast2_module_x11('firewall', target_match => 'firewall-start-page');

    verify_interface(device => $iface, zone => 'default');
    verify_zone(name => 'public', interfaces => $iface, default => 'default');
    set_default_zone 'trusted';
    verify_zone(name => 'trusted', interfaces => $iface, default => 'default', menu_selected => 1);

    record_info('Interface/Zones', "Verify zone info assigning interface to different zone");
    change_interface_zone 'public';
    verify_interface(device => $iface, zone => 'public');
    verify_zone(name => 'public', interfaces => $iface);
    verify_zone(name => 'trusted', default => 'default');

    record_info('Zones', "Configure zone adding service and port");
    configure_zone(zone => 'trusted', service => 'bitcoin', port => '7777');

    send_key $cmd{accept};
}

sub verify_firewalld_configuration {
    record_info('Verify firewall', 'Verify firewall configuration');
    select_console 'root-console';
    assert_script_run 'firewall-cmd --state | grep running';
    assert_script_run 'firewall-cmd --list-interfaces --zone=public | grep ' . iface;
    assert_script_run 'firewall-cmd --list-all --zone=trusted | grep -E \'services: bitcoin\'';
    assert_script_run 'firewall-cmd --list-all --zone=trusted | grep -E \'ports: 7777/tcp\'';
}

sub run {
    select_console 'x11';

    if (is_sle('15+') || is_leap('15.0+') || is_tumbleweed) {
        verify_service_stopped;
        verify_service_started;
        configure_firewalld;
        verify_firewalld_configuration;
        select_console 'x11', await_console => 0;
    }
    else {
        select_console 'root-console';
        zypper_call('in yast2-http-server apache2 apache2-prefork', timeout => 1200);
        select_console 'x11', await_console => 0;
        y2_module_guitest::launch_yast2_module_x11('firewall', match_timeout => 60);
        susefirewall2;
    }
}

1;
