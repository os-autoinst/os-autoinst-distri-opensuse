# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test WiFi setup with wicked (WPA-EAP/PEAP/MSCHAPv2 with DHCP)
# - WiFi Access point:
#   - Use virtual wlan devices
#   - AP with hostapd is running in network namespace
#   - dnsmasq for DHCP server
#   - freeradius as authenticator
# - WiFi Station:
#   - connect using ifcfg-wlan1 and `wicked ifup`
#   - check if STA is associated to AP
#   - ping both directions AP <-> STA
#
# Maintainer: cfamullaconrad@suse.com


use Mojo::Base 'wicked::wlan';
use testapi;

has ssid => 'EAP protected WLAN';

my $hostapd_conf = q(
    ctrl_interface=/var/run/hostapd
    interface={{ref_ifc}}
    driver=nl80211
    country_code=DE
    ssid={{ssid}}
    channel=1
    auth_algs=3
    wpa=2
    wpa_key_mgmt=WPA-EAP
    wpa_pairwise=CCMP
    rsn_pairwise=CCMP
    group_cipher=CCMP

    # Require IEEE 802.1X authorization
    ieee8021x=1
    eapol_version=2
    eap_message=ping-from-hostapd

    ## RADIUS authentication server
    nas_identifier=the_ap
    auth_server_addr=127.0.0.1
    auth_server_port=1812
    auth_server_shared_secret=testing123
);

my $ifcfg_wlan = q(
    BOOTPROTO='dhcp'
    STARTMODE='auto'

    # Global settings
    WIRELESS_AP_SCANMODE='1'
    WIRELESS_WPA_DRIVER='nl80211'

    # Network settings
    WIRELESS_ESSID='{{ssid}}'
    WIRELESS_AUTH_MODE='eap'
    WIRELESS_CLIENT_CERT='/etc/raddb/certs/client.crt'
    WIRELESS_CLIENT_KEY='/etc/raddb/certs/client.key'
    WIRELESS_CLIENT_KEY_PASSWORD='whatever'
    WIRELESS_EAP_AUTH='mschapv2'
    WIRELESS_EAP_MODE='PEAP'
    WIRELESS_MODE='Managed'
    WIRELESS_WPA_ANONID='anonymous'
    WIRELESS_WPA_IDENTITY='{{eap_user}}'
    WIRELESS_WPA_PASSWORD='{{eap_password}}'
);

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    # Setup ref
    $self->netns_exec('ip addr add dev wlan0 ' . $self->ref_ip . '/24');
    $self->restart_DHCP_server();
    $self->netns_exec('radiusd -d /etc/raddb/');
    $self->write_cfg('hostapd.conf', $hostapd_conf);
    $self->netns_exec('hostapd -B hostapd.conf');

    # Setup sut
    $self->write_cfg('/etc/sysconfig/network/ifcfg-' . $self->sut_ifc, $ifcfg_wlan);
    $self->wicked_command('ifup', $self->sut_ifc);

    # Check
    $self->assert_sta_connected();
    $self->assert_connection();
}

1;
