# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test WiFi setup with wicked for wpa3 transition
#          (WPA-PSK or SAE with DHCP)
#   - The AP is connfiguered to allow WPA-PSK and SAE connections
#   - Connect to AP with WPA-PSK
#   - Connect to AP with WPA-PSK + PMF
#   - Connect to AP with SAE
#   - Connect to AP with SAE + PMF
#   - Each connection is checked with data bi-directional traffic
#
# Maintainer: cfamullaconrad@suse.com


use Mojo::Base 'wicked::wlan';
use testapi;

has wicked_version => '>=0.6.70';
has need_key_mgmt => 'SAE';
has ssid => 'Virtual WiFi SAE Secured';
has psk => 'TopSecretWifiPassphrase!';

has hostapd_conf => q(
        ctrl_interface=/var/run/hostapd
        interface={{ref_ifc}}
        driver=nl80211
        country_code=DE
        hw_mode=g
        channel=3
        ieee80211n=1
        ssid={{ssid}}
        ieee80211w=2
        wpa=2
        wpa_key_mgmt=SAE
        wpa_pairwise=CCMP
        group_cipher=CCMP
        wpa_passphrase={{psk}}
);

has ifcfg_wlan => sub { [
        q(
        # By default, 80211mac_hwsim has SAE capabilities, so autoselection should work
        BOOTPROTO='dhcp'
        STARTMODE='auto'

        WIRELESS_ESSID='{{ssid}}'
        WIRELESS_WPA_PSK='{{psk}}'
    ),
        q(
        BOOTPROTO='dhcp'
        STARTMODE='auto'

        WIRELESS_KEY_MGMT=SAE
        WIRELESS_CIPHER_GROUP=CCMP
        WIRELESS_CIPHER_PAIRWISE=CCMP
        WIRELESS_PMF=required
        WIRELESS_ESSID='{{ssid}}'
        WIRELESS_WPA_PSK='{{psk}}'
    )
] };



1;
