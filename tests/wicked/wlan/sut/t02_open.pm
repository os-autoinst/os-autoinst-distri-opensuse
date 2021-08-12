# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test WiFi setup with wicked (Open with DHCP)
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

has ssid => 'Open Virutal WiFi';

has hostapd_conf => q(
    ctrl_interface=/var/run/hostapd
    interface={{ref_ifc}}
    driver=nl80211
    country_code=DE
    ssid={{ssid}}
    channel=0
    hw_mode=g
);

has ifcfg_wlan => sub { [
        q(
            STARTMODE='auto'
            BOOTPROTO='dhcp'

            WIRELESS_MODE='Managed'
            WIRELESS_ESSID='{{ssid}}'
        ),
        q(
            STARTMODE='auto'
            BOOTPROTO='dhcp'

            WIRELESS_ESSID='{{ssid}}'
        ),
        q(
            STARTMODE='auto'
            BOOTPROTO='dhcp'

            WIRELESS_AUTH_MODE='open'
            WIRELESS_ESSID='{{ssid}}'
        )
] };

1;
