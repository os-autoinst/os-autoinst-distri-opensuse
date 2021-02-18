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

has use_radius => 1;
has ssid       => 'EAP protected WLAN';

has hostapd_conf => q(
    ctrl_interface=/var/run/hostapd
    interface={{ref_ifc}}
    driver=nl80211
    country_code=DE
    ssid={{ssid}}
    channel=1
    hw_mode=g
    ieee80211n=1
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

has ifcfg_wlan => q(
    BOOTPROTO='dhcp'
    STARTMODE='auto'

    # Global settings
    WIRELESS_AP_SCANMODE='1'
    WIRELESS_WPA_DRIVER='nl80211'

    # Network settings
    WIRELESS_ESSID='{{ssid}}'
    WIRELESS_AUTH_MODE='eap'
    WIRELESS_EAP_AUTH='mschapv2'
    WIRELESS_EAP_MODE='PEAP'
    WIRELESS_MODE='Managed'
    WIRELESS_WPA_ANONID='anonymous'
    WIRELESS_WPA_IDENTITY='{{eap_user}}'
    WIRELESS_WPA_PASSWORD='{{eap_password}}'
);

1;
