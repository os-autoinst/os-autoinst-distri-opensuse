# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test WiFi setup with wicked (WPA-PSK with DHCP)
#          the configuration contains multiple network configurations.
# - WiFi Access point:
#   - Use virtual wlan devices
#   - AP with hostapd is running in network namespace
#   - dnsmasq for DHCP server
# - WiFi Station:
#   - connect using ifcfg-wlan1 and `wicked ifup`
#   - check if STA is associated to AP
#   - ping both directions AP <-> STA
#
# Maintainer: cfamullaconrad@suse.com


use Mojo::Base 'wicked::wlan';
use testapi;

has wicked_version => '>=0.6.66';
has ssid           => 'Virtual WiFi PSK Secured';
has psk            => 'TopSecretWifiPassphrase!';

has hostapd_conf => q(
    ctrl_interface=/var/run/hostapd
    interface={{ref_ifc}}
    driver=nl80211
    country_code=DE
    ssid={{ssid}}
    channel=11
    hw_mode=g
    ieee80211n=1
    wpa=3
    wpa_key_mgmt=WPA-PSK
    wpa_pairwise=TKIP CCMP
    wpa_passphrase={{psk}}
    auth_algs=3
    beacon_int=100
);

has ifcfg_wlan => sub { [
        q(
        BOOTPROTO='dhcp'
        STARTMODE='auto'

        WIRELESS_AUTH_MODE='psk'
        WIRELESS_ESSID='NO_NOT_FIND_ME'
        WIRELESS_WPA_PSK='SOMETHING!!'

        WIRELESS_AUTH_MODE_1='psk'
        WIRELESS_ESSID_1='{{ssid}}'
        WIRELESS_WPA_PSK_1='{{psk}}'
    ),
        q(
        BOOTPROTO='dhcp'
        STARTMODE='auto'

        WIRELESS_AUTH_MODE='psk'
        WIRELESS_ESSID='{{ssid}}'
        WIRELESS_WPA_PSK='{{psk}}'

        WIRELESS_AUTH_MODE_2='psk'
        WIRELESS_ESSID_2='NO_NOT_FIND_ME'
        WIRELESS_WPA_PSK_2='SOMETHING!!'
    ),
        q(
        BOOTPROTO='dhcp'
        STARTMODE='auto'

        WIRELESS_ESSID='{{ssid}}'
        WIRELESS_WPA_PSK='{{psk}}'

        WIRELESS_ESSID_2='NO_NOT_FIND_ME'
        WIRELESS_WPA_PSK_2='SOMETHING!!'
    )
] };


1;
