# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test WiFi setup with wicked (Open static IP)
# - WiFi Access point:
#   - Use virtual wlan devices
#   - AP with hostapd is running in network namespace
# - WiFi Station:
#   - connect using ifcfg-wlan1 and `wicked ifup`
#   - check if STA is associated to AP
#   - ping both directions AP <-> STA
#
# Maintainer: cfamullaconrad@suse.com


use Mojo::Base 'wicked::wlan';
use testapi;

has use_dhcp => 0;
has ssid => 'Open Virtual WiFi StaticIP';

has hostapd_conf => q(
    ctrl_interface=/var/run/hostapd
    interface={{ref_ifc}}
    driver=nl80211
    country_code=DE
    ssid={{ssid}}

    channel=0
    hw_mode=g
);

has ifcfg_wlan => q(
    STARTMODE='auto'

    BOOTPROTO='static'
    IPADDR='{{sut_ip}}'
    NETMASK='255.255.255.0'

    WIRELESS_MODE='Managed'
    WIRELESS_ESSID='{{ssid}}'
);

1;
