# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test WiFi setup with wicked (WPA-EAP-SUITE-B-192/TTLS/PAP with DHCP)
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

has wicked_version => '>=0.6.70';
has need_key_mgmt => 'WPA-EAP-SUITE-B-192';
has use_radius => 1;
has ssid => 'WPA3-EAP protected WLAN';

has hostapd_conf => q(
    ctrl_interface=/var/run/hostapd
    interface={{ref_ifc}}
    driver=nl80211
    country_code=DE
    ssid={{ssid}}
    channel=6
    hw_mode=g
    ieee80211n=1
    auth_algs=3
    wpa=2
    wpa_key_mgmt=WPA-EAP-SUITE-B WPA-EAP-SUITE-B-192
    rsn_pairwise=CCMP
    group_cipher=CCMP
    ieee80211w=2

    # Require IEEE 802.1X authorization
    ieee8021x=1
    eapol_version=2
    eap_message=msg-from-hostapd

    ## RADIUS authentication server
    auth_server_addr=127.0.0.1
    auth_server_port=1812
    auth_server_shared_secret=testing123
    nas_identifier=the_ap2
);

has ifcfg_wlan => sub { [
        q(
            BOOTPROTO='dhcp'
            STARTMODE='auto'

            # Network settings
            WIRELESS_ESSID='{{ssid}}'
            WIRELESS_KEY_MGMT='WPA-EAP-SUITE-B'
            WIRELESS_EAP_AUTH='pap'
            WIRELESS_EAP_MODE='TTLS'
            WIRELESS_CA_CERT='{{ca_cert}}'
            WIRELESS_WPA_IDENTITY='{{eap_user}}'
            WIRELESS_WPA_PASSWORD='{{eap_password}}'
        ),
        q(
            BOOTPROTO='dhcp'
            STARTMODE='auto'

            # Network settings
            WIRELESS_ESSID='{{ssid}}'
            WIRELESS_KEY_MGMT='WPA-EAP-SUITE-B-192'
            WIRELESS_EAP_AUTH='pap'
            WIRELESS_EAP_MODE='TTLS'
            WIRELESS_CA_CERT='{{ca_cert}}'
            WIRELESS_WPA_IDENTITY='{{eap_user}}'
            WIRELESS_WPA_PASSWORD='{{eap_password}}'
        ),
        q(
            BOOTPROTO='dhcp'
            STARTMODE='auto'

            # Network settings
            WIRELESS_ESSID='{{ssid}}'
            WIRELESS_KEY_MGMT='WPA-EAP-SUITE-B-192'
            WIRELESS_PMF=required
            WIRELESS_EAP_AUTH='pap'
            WIRELESS_EAP_MODE='TTLS'
            WIRELESS_CA_CERT='{{ca_cert}}'
            WIRELESS_WPA_IDENTITY='{{eap_user}}'
            WIRELESS_WPA_PASSWORD='{{eap_password}}'
        )
] };


1;
