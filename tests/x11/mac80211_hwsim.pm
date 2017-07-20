# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: tests the wpa2-enterprise capabilites of 'hostapd' and 'NetworkManager'
# Maintainer: Nick Singer <nsinger@suse.de>
# Tags: poo#20306

use base 'x11test';
use y2x11test 'launch_yast2_module_x11';
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

    select_console 'x11';
    $self->configure_system;
    $self->connect_to_network;
    $self->enter_NM_credentials;
    $self->handle_polkit_root_auth;

    # the root console will most likely be polluted with dmesg output
    select_console 'root-console', await_console => 0;
    send_key 'ctrl-l';
    assert_screen 'root-console';
    $self->NM_disable_ip;

    # we've the NetworkManager window open on x11 so the await_console
    # needle cannot match so we rely on the assert_and_click from
    # connect_to_network
    select_console 'x11', 'await_console' => 0;

    # connect again to see if NM has a "connection" after we disabled v4 and v6
    $self->connect_to_network;
    assert_screen 'network_manager-network_connected';
    assert_and_click 'network_manager-close-click';
}

sub install_packages {
    my $required_packages = 'NetworkManager hostapd';
    type_string "# installing required packages\n";
    pkcon_quit;
    zypper_call("in $required_packages");
}

sub prepare_NM {
    type_string "# configure NetworkManager to ignore one of the hwsim interfaces\n";
    release_key 'shift';    # workaround for stuck key

    my $nm_conf = '/etc/NetworkManager/NetworkManager.conf';
    assert_script_run "echo \"[keyfile]\" >> $nm_conf";
    assert_script_run "echo \"unmanaged-devices=interface-name:wlan0,interface-name:hwsim*\" >> $nm_conf";
}

sub connect_to_network {
    my $self = shift;

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
    my $self = shift;

    # we expect here to enter our credentials for this wireless network
    assert_screen 'network_manager-wpa2_authentication';

    # When we land at this dialog, nothing has focus.
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

    # we have to change the networkmanager form wicked to NetworkManager
    y2x11test::launch_yast2_module_x11 module => 'lan';
    assert_screen 'yast2_control-center_network-opened';

    # switch to 'Global options'
    assert_and_click 'yast2_network-global_options-click';
    # open the networkmanager dropdown and select 'NetworkManager'
    assert_and_click 'yast2_network-nm_selection-click';
    assert_and_click 'yast2_network-network_manager-click';
    assert_screen 'yast2_network-network_manager-selected';
    # now apply the settings
    assert_and_click 'yast2_network-apply_settings-click';
    assert_and_click 'yast2_network-applet_warning-click';
    assert_screen 'yast2_network-is_applying';

    if (check_screen 'yast2_network-error_dialog') {
        record_soft_failure 'boo#1049097';
        assert_and_click 'yast2_network-error_dialog';
    }
}

sub reload_services {
    type_string "# reload required services\n";
    assert_script_run 'systemctl restart NetworkManager';
    assert_script_run 'systemctl restart hostapd';
    assert_script_run 'systemctl is-active hostapd';
}

sub NM_disable_ip {
    type_string "# disable IPv4 and IPv6 so NM thinks we are online even without dhcp\n";
    my $nm = 'nmcli connection ';
    assert_script_run "connection_uuid=\$($nm show | grep foobar | awk '{ print \$2 }')";
    assert_script_run "$nm modify \$connection_uuid ipv4.method disabled";
    assert_script_run "$nm modify \$connection_uuid ipv6.method ignore";
}

sub handle_polkit_root_auth {
    assert_screen 'Policykit-root';
    wait_still_screen 3;    # the input takes a couple of seconds to be ready
    type_password;
    send_key 'ret';
}
1;
