# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: YaST2 Firewall UI test checks verious configurations and settings of firewall
# Make sure yast2 firewall can opened properly. Configurations can be changed and written correctly.
# Maintainer: Joaquín Rivera <jeriveramoya@suse.com>

use base "y2x11test";
use strict;
use testapi;
use utils;
use version_utils qw(is_sle is_leap is_tumbleweed);
use yast2_shortcuts '%fw';
use network_utils 'iface';

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
    my $self = shift;

    record_info('Start-Up', "Managing the firewalld service: Stop");
    select_console 'x11', await_console => 0;
    $self->launch_yast2_module_x11('firewall', target_match => 'firewall-start-page');
    assert_screen 'yast2_firewall_start-up';
    assert_screen 'yast2_firewall_service_status_running';
    send_key $fw{service_stop};
    assert_screen [qw(yast2_firewall_service_status_stopped generic-desktop)];
    if (match_has_tag('generic-desktop')) {
        record_soft_failure "bsc#1114677 - Dialog dissapear after switching service status";
    }
    assert_screen 'yast2_firewall_service_status_stopped';
    wait_screen_change { send_key $cmd{accept} };
    assert_screen 'generic-desktop';

    select_console 'root-console';
    if (script_run("firewall-cmd --state 2>&1 | grep 'not running'") != 0) {
        record_soft_failure "bsc#1114807 - service does not stop ";
        return;
    }
}

sub verify_service_started {
    my $self = shift;

    record_info('Start-Up', "Managing the firewalld service: Start");
    select_console 'x11', await_console => 0;
    $self->launch_yast2_module_x11('firewall', target_match => 'firewall-start-page');
    assert_screen 'yast2_firewall_start-up';
    assert_screen 'yast2_firewall_service_status_stopped';
    send_key $fw{service_start};
    assert_screen [qw(yast2_firewall_service_status_running generic-desktop)];
    if (match_has_tag('generic-desktop')) {
        record_soft_failure "bsc#1114677 - Dialog dissapear after switching service status";
    }
    assert_screen 'yast2_firewall_service_status_running';
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
    type_string "$zone\n";
}

sub verify_zone {
    my (%args) = @_;

    my $interfaces = $args{interfaces} //= 'no_interfaces';
    my $default    = $args{default}    //= 'no_default';

    assert_and_click 'yast2_firewall_zones';
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
        assert_screen 'yast2_firewall_zone_service_warning';
        send_key $fw{yes};
        assert_screen 'yast2_firewall_zone_ports_tab_selected';
        send_key $fw{tcp};
        type_string '7777';
    }
}

sub configure_firewalld {
    my $self = shift;

    record_info('Interface/Zones ', "Verify zone info changing default zone when interface assigned to default zone");
    my $iface = iface;

    select_console 'x11', await_console => 0;
    $self->launch_yast2_module_x11('firewall', target_match => 'firewall-start-page');

    verify_interface(device => $iface, zone => 'default');
    verify_zone(name => 'public', interfaces => $iface, default => 'default');
    set_default_zone 'trusted';
    verify_zone(name => 'trusted', interfaces => $iface, default => 'default');

    record_info('Interface/Zones', "Verify zone info assigning interface to different zone");
    change_interface_zone 'public';
    verify_interface(device => $iface, zone => 'public');
    verify_zone(name => 'public',  interfaces => $iface);
    verify_zone(name => 'trusted', default    => 'default');

    record_info('Zones', "Configure zone adding service and port");
    configure_zone(zone => 'trusted', service => 'bitcoin', port => '7777');

    send_key $cmd{accept};
}

sub verify_firewalld_configuration {
    select_console 'root-console';
    assert_script_run 'firewall-cmd --state | grep running';
    if (script_run('firewall-cmd --list-interfaces --zone=public | grep ' . $fw{interface_device})) {
        record_soft_failure "bsc#1114673 - Interface not assigned to the right zone in first run";
    }
    assert_script_run 'firewall-cmd --list-all --zone=trusted | grep -E \'services: bitcoin\'';
    assert_script_run 'firewall-cmd --list-all --zone=trusted | grep -E \'ports: 7777/tcp\'';
}

sub run {
    my $self = shift;

    if (is_sle('15+') || is_leap('15.0+') || is_tumbleweed) {
        if ($self->verify_service_stopped) {
            $self->verify_service_started;
        }
        $self->configure_firewalld;
        verify_firewalld_configuration;
        select_console 'x11', await_console => 0;
    }
    else {
        zypper_call('in yast2-http-server apache2 apache2-prefork', timeout => 1200);
        select_console 'x11', await_console => 0;
        $self->launch_yast2_module_x11('firewall', match_timeout => 60);
        susefirewall2;
    }
}

1;
