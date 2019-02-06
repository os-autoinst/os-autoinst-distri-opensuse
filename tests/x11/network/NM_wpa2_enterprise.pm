# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Tests the wpa2-enterprise capabilites of 'hostapd' and 'NetworkManager' based on the setup hwsim_wpa2-enterprise_setup does
# Maintainer: Nick Singer <nsinger@suse.de>
# Tags: poo#20306

use base 'x11test';
use strict;
use warnings;
use testapi;
use utils;
use x11utils 'ensure_unlocked_desktop';

sub run {
    my $self = shift;

    $self->connect_to_network;
    $self->enter_NM_credentials;
    $self->handle_polkit_root_auth;

    # the root console will most likely be polluted with dmesg output
    select_console 'root-console', await_console => 0;
    wait_still_screen 6;
    clear_console;
    assert_screen 'root-console';
    $self->NM_disable_ip;

    # we've the NetworkManager window open on x11 so the await_console
    # needle cannot match so we rely on the assert_and_click from
    # connect_to_network
    select_console 'x11', await_console => 0;
    ensure_unlocked_desktop;

    # connect again to see if NM has a "connection" after we disabled v4 and v6
    $self->connect_to_network;
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

    # When we land at the credentials dialog, nothing has focus.
    # The first tab results in focusing the first input field.
    # But since we want the dropdown field one above, we have
    # to go up by pressing "Shift+Tab".

    send_key 'tab';
    send_key 'shift-tab';

    # then we open the dropdown
    send_key 'spc';
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
    type_string "# disable IPv4 and IPv6 so NM thinks we are online even without dhcp\n";
    my $nm = 'nmcli connection ';
    assert_script_run "connection_uuid=\$($nm show | grep foobar | awk '{ print \$2 }')";
    assert_script_run "$nm modify \$connection_uuid ipv4.method disabled";
    assert_script_run "$nm modify \$connection_uuid ipv6.method ignore";
}

sub post_fail_hook {
    my ($self) = @_;
    select_console 'log-console';
    $self->save_and_upload_systemd_unit_log($_) foreach qw(NetworkManager hostapd);
    $self->SUPER::post_fail_hook;
}

1;
