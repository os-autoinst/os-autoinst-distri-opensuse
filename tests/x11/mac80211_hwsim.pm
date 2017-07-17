# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: mac80211 hw test
# Maintainer: Nick Singer <nsinger@suse.de>
# Tags: poo#20306

use base 'x11test';
use y2x11test qw(launch_yast2_module_x11);
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $self = shift;
    select_console 'root-console';
    assert_script_run "modprobe mac80211_hwsim radios=2 |& tee /dev/$serialdev";
    save_screenshot;

    $self->install_packages;
    $self->prepare_NM;
    $self->generate_certs;
    $self->configure_hostapd;
    $self->reload_services;
    type_string "exit\n";

    select_console 'x11';
    $self->configure_system;
    $self->connect_to_network;

    # root password
    $self->handle_polkit_root_auth;

    select_console 'root-console';
    $self->NM_disable_ip;
    select_console 'x11';
}

sub install_packages {
    my $required_packages = 'NetworkManager hostapd';
    type_string "# installing required packages\n";
    pkcon_quit;
    zypper_call("in $required_packages");
}

sub prepare_NM {
    type_string "# configure NetworkManager to ignore one of the hwsim interfaces\n";

    my $nm_conf = '/etc/NetworkManager/NetworkManager.conf';
    assert_script_run "echo \"[keyfile]\" >> $nm_conf";
    assert_script_run "echo \"unmanaged-devices=interface-name:wlan0,interface-name:hwsim*\" >> $nm_conf";
}

sub connect_to_network {
    my $self = shift;

    # open the gnome widget
    assert_and_click 'gnome_widget';
    # select 'wifi 1'
    assert_and_click 'gnome_widget-network_selection-click';
    # click on 'select network'
    assert_and_click 'gnome_widget-network_search-click';
    # check if our self created wifi is available
    assert_screen 'gnome_widget-network_found_networks';
    # select it
    assert_and_click 'gnome_widget-choose_network-click';
    # and click on 'connect'
    assert_and_click 'gnome_widget-connect-click';
    $self->enter_NM_credentials;
}

sub enter_NM_credentials {
    my $self = shift;
    # we expect here to enter our credentials for this wireless network
    assert_screen 'network_manager-wpa2_authentication';

    # When we land at this dialog, nothing has focus.
    # The first tab results in focusing the first input field.
    # But since we want the dropdown field one above, we have
    # to go up by pressing "Shift+Tab".

    send_key 'tab';
    hold_key 'shift';
    send_key 'tab';
    release_key 'shift';

    # then we open the dropdown
    send_key 'spc';
    # and select 'Protected EAP (PEAP)'
    send_key_until_needlematch('network_manager-peap_selected', 'up');
    send_key 'ret';

    # enter anonymous identity
    type_string 'franz.nord@example.com';

    # select 'No CA certificate needed'
    send_key 'tab';
    send_key 'tab';
    send_key 'tab';
    send_key 'tab';
    send_key 'spc';
    
    # 2x tab, franz.nord@example.com
    send_key 'tab';
    send_key 'tab';
    send_key 'tab';
    type_string 'franz.nord@example.com';
    send_key 'tab';
    type_string 'nots3cr3t';

    # aat 'connect'
    assert_and_click 'network_manager-connect-click';
}

sub generate_certs {
    assert_script_run 'mkdir -p wpa_enterprise_certificates/{CA,server}';
    assert_script_run 'cd wpa_enterprise_certificates';

    type_string "# generate private keys\n";
    assert_script_run 'openssl genrsa -out CA/CA.key 4096';
    assert_script_run 'openssl genrsa -out server/server.key 4096';
    save_screenshot;

    type_string "# generate certificate for CA\n";
    assert_script_run 'openssl req -x509 -new -nodes -key CA/CA.key -sha256 -days 3650 -out CA/CA.crt -subj "/"';

    type_string "# generate certificate signing request for server\n";
    assert_script_run 'openssl req -new -key server/server.key -out server/server.csr -subj "/"';
    save_screenshot;

    type_string "# sign csr with the key/cert from the CA\n";
    assert_script_run 'openssl x509 -req -in server/server.csr -CA CA/CA.crt -CAkey CA/CA.key -CAcreateserial -out server/server.crt -days 3650 -sha256';
    save_screenshot;
}

sub configure_hostapd {
    type_string "# configure hostapd\n";
    assert_script_run 'wget -O /etc/hostapd.conf ' . data_url('hostapd_wpa2-enterprise.conf');

    type_string "# create wpa2 enterprise user\n";
    assert_script_run 'echo \"franz.nord@example.com\" PEAP >> /etc/hostapd.eap_user';
    assert_script_run 'echo \"franz.nord@example.com\" MSCHAPV2 \"nots3cr3t\" [2]>> /etc/hostapd.eap_user';
}

sub configure_system {
    my $self = shift;
    y2x11test::launch_yast2_module_x11;
    $self->yast_search('Network Settings');

    # assert_and_click 'yast2-networksettings'
    assert_and_click 'yast2_control-center_network-check';
    # assert 'networksettings_open'
    assert_screen 'yast2_control-center_network-opened';
    # aac 'global options'
    assert_and_click 'yast2_network-global_options-click';
    # aac 'network setup method'
    assert_and_click 'yast2_network-nm_selection-click';
    # aac 'NetworkManager
    assert_and_click 'yast2_network-network_manager-click';
    assert_screen 'yast2_network-network_manager-selected';
    assert_and_click 'yast2_network-apply_settings-click';
    # aac 'ok'
    assert_and_click 'yast2_network-applet_warning-click';
    assert_screen 'yast2_network-is_applying';
    # assert 'saving-is-running'
    # softfail yast2 error
    #   aac 'ok'
    if (check_screen 'yast2_network-error_dialog') {
        record_soft_failure 'bsc#TODO';
        assert_and_click 'yast2_network-error_dialog';
    }
}

sub reload_services {
    type_string "# reload required services\n";
    assert_script_run 'systemctl restart NetworkManager';
    assert_script_run 'systemctl restart hostapd';
}

sub yast_search {
    my ($self, $name) = @_;
    # on openSUSE we have a Qt setup with keyboard shortcut
    if (check_var('DISTRI', 'opensuse')) {
        send_key 'alt-s';
    }
    # with the gtk interface we have to click as there is no shortcut
    elsif (check_var('DISTRI', 'sle')) {
        assert_screen([qw(yast2_control-center_search_clear yast2_control-center_search)], no_wait => 1);
        if (match_has_tag 'yast2_control-center_search') {
            assert_and_click 'yast2_control-center_search';
        }
        else {
            assert_and_click 'yast2_control-center_search_clear';
        }
    }
    type_string $name if $name;
}

sub NM_disable_ip {
    type_string "# disable IPv4 and IPv6 so NM thinks we are online even without dhcp\n";
    my $nm = 'nmcli connection ';
    my $connection_uuid = script_output("$nm show | grep foobar | awk '{ print \$2 }'");
    assert_script_run "$nm modify $connection_uuid ipv4.method disabled";
    assert_script_run "$nm modify $connection_uuid ipv6.method ignore";
}

sub handle_polkit_root_auth {
    assert_screen 'Policykit-root';
    type_password;
    send_key 'ret';
}
1;
