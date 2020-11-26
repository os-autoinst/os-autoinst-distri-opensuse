# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test WiFi setup with wicked (WPA-PSK with DHCP)
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

has ssid => 'Virtual WiFi PSK Secured';
has psk  => 'TopSecretWifiPassphrase!';

has hostapd_conf => q(
    ctrl_interface=/var/run/hostapd
    interface={{ref_ifc}}
    driver=nl80211
    country_code=DE
    ssid={{ssid}}
    channel=0
    hw_mode=b
    wpa=3
    wpa_key_mgmt=WPA-PSK
    wpa_pairwise=TKIP CCMP
    wpa_passphrase={{psk}}
    auth_algs=3
    beacon_int=100
);

has ifcfg_wlan => q(
    BOOTPROTO='dhcp'
    STARTMODE='auto'

    WIRELESS_MODE='Managed'
    WIRELESS_AUTH_MODE='psk'
    WIRELESS_ESSID='{{ssid}}'
    WIRELESS_WPA_PSK='{{psk}}'
);

1;
