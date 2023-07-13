# SUSE's openQA tests
#
# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: NetworkManager
# Summary: Tests the wpa2-enterprise capabilites of 'hostapd' and 'NetworkManager' based on the setup hwsim_wpa2-enterprise_setup does
# Maintainer: Nick Singer <nsinger@suse.de>
# Tags: poo#20306

use base 'x11test';
use strict;
use warnings;
use testapi;
use utils;
use Utils::Logging 'save_and_upload_systemd_unit_log';

sub run {
    my $self = shift;

    $self->connect_to_network;
    $self->enter_NM_credentials;
    $self->handle_polkit_root_auth;

    x11_start_program('xterm');
    become_root;
    # disable IPv4 and IPv6 so NM thinks we are online even without dhcp
    $self->NM_disable_ip;
    enter_cmd "exit";
    enter_cmd "exit";

    # wait for auto reconnect to see if NM has a "connection" after we disabled v4 and v6
    wait_still_screen;
    assert_screen [qw(network_manager-network_connected network_manager-wrong_card_selected)];
    if (match_has_tag 'network_manager-wrong_card_selected') {
        record_soft_failure 'boo#1079320';
        assert_and_click 'network_manager-wrong_card_selected';
        assert_screen 'network_manager-network_connected';
    }
    assert_and_click 'network_manager-close-click';
}

sub connect_to_network {
    # open the wifi widget
    assert_and_click 'gnome_widget';
    # select 'wifi 1' (The one not beeing ignored by NM)
    assert_and_click 'gnome_widget-network_selection-click';
    # click on 'select network'
    assert_and_click 'gnome_widget-network_search-click';
    # check if our self created wifi is available
    assert_screen 'gnome_widget-network_found_networks';
    # select it
    assert_and_click 'gnome_widget-choose_network-click';
    # and click on 'connect'
    assert_and_click 'gnome_widget-connect-click';
}

sub enter_NM_credentials {
    # we expect here to enter our credentials for this wireless network
    assert_screen([qw(network_manager-wpa2_authentication generic_gnome_configuration-boo1060079)]);
    if (match_has_tag 'generic_gnome_configuration-boo1060079') {
        assert_and_click 'generic_gnome_configuration-boo1060079';
        assert_and_click 'gnome_settings-wifi-found_network';
        assert_screen 'network_manager-wpa2_authentication';
    }

    assert_and_click 'network_manager-authentication';
    # and select 'Protected EAP (PEAP)'
    send_key_until_needlematch('network_manager-peap_selected', 'down');
    send_key 'ret';

    # enter anonymous identity
    type_string 'franz.nord@example.com';

    # select 'No CA certificate needed'
    send_key 'tab';
    send_key 'tab';
    send_key 'tab';
    send_key 'tab';
    send_key 'spc';

    # jump to username
    send_key 'tab';
    send_key 'tab';
    send_key 'tab';
    type_string 'franz.nord@example.com';
    send_key 'tab';
    # and enter the password for this specific user (definded in hostapd config)
    type_password 'nots3cr3t';

    # finally click on 'connect'
    assert_and_click 'network_manager-connect-click';
}

sub handle_polkit_root_auth {
    assert_screen 'Policykit-root';
    wait_still_screen 3;    # the input takes a couple of seconds to be ready
    type_password;
    send_key 'ret';
}

sub NM_disable_ip {
    my $nm = 'nmcli connection ';
    assert_script_run "connection_uuid=\$($nm show | grep foobar | awk '{ print \$2 }')";
    assert_script_run "$nm modify \$connection_uuid ipv4.method disabled";
    assert_script_run "$nm modify \$connection_uuid ipv6.method ignore";
}

sub post_fail_hook {
    my ($self) = @_;
    select_console 'log-console';
    save_and_upload_systemd_unit_log($_) foreach qw(NetworkManager hostapd);
    $self->SUPER::post_fail_hook;
}

1;
