# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test WiFi setup with wicked (WEP with DHCP)
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
has ssid => 'WEP-Secured';
has key0_104_str => "0123456789123";
has key0_104_hex => "30313233343536373839313233";
has key0_104_hex2 => "3031-3233-3435-3637-3839-3132-33";
has key1_104_hex => "01020304050607080900010203";
has key2_40_hex => "0102030405";
has key3_40_str => "01234";
has key3_40_hex => "3031323334";
has key3_40_hex2 => "3031-3233-34";

has hostapd_conf => sub { [
        q(
            ctrl_interface=/var/run/hostapd
            interface={{ref_ifc}}
            driver=nl80211
            country_code=DE
            ssid={{ssid}}
            channel=1
            hw_mode=g
            ieee80211n=1
            auth_algs=2

            wep_default_key=0
            wep_key0="{{key0_104_str}}"
            wep_key1={{key1_104_hex}}
            wep_key2={{key2_40_hex}}
            wep_key3="{{key3_40_str}}"
        ),
        q(
            ctrl_interface=/var/run/hostapd
            interface={{ref_ifc}}
            driver=nl80211
            country_code=DE
            ssid={{ssid}}
            channel=6
            hw_mode=g
            ieee80211n=1
            auth_algs=2

            wep_default_key=1
            wep_key0="{{key0_104_str}}"
            wep_key1={{key1_104_hex}}
            wep_key2={{key2_40_hex}}
            wep_key3="{{key3_40_str}}"
        ),
        q(
            ctrl_interface=/var/run/hostapd
            interface={{ref_ifc}}
            driver=nl80211
            country_code=DE
            ssid={{ssid}}
            channel=11
            hw_mode=g
            ieee80211n=1
            auth_algs=2

            wep_default_key=2
            wep_key0="{{key0_104_str}}"
            wep_key1={{key1_104_hex}}
            wep_key2={{key2_40_hex}}
            wep_key3="{{key3_40_str}}"
        ),
        q(
            ctrl_interface=/var/run/hostapd
            interface={{ref_ifc}}
            driver=nl80211
            country_code=DE
            ssid={{ssid}}
            channel=3
            hw_mode=g
            ieee80211n=1
            auth_algs=2

            wep_default_key=3
            wep_key0="{{key0_104_str}}"
            wep_key1={{key1_104_hex}}
            wep_key2={{key2_40_hex}}
            wep_key3="{{key3_40_str}}"
        ),
] };

has ifcfg_wlan => sub { [
        q(
            STARTMODE='auto'
            BOOTPROTO='dhcp'

            WIRELESS_ESSID='{{ssid}}'
            WIRELESS_AUTH_MODE='shared'
            WIRELESS_KEY_0="h:{{key0_104_hex}}"
            WIRELESS_KEY_1="h:{{key1_104_hex}}"
            WIRELESS_KEY_2="h:{{key2_40_hex}}"
            WIRELESS_KEY_3="h:{{key3_40_hex}}"
        ),
        q(
            STARTMODE='auto'
            BOOTPROTO='dhcp'

            WIRELESS_ESSID='{{ssid}}'
            WIRELESS_AUTH_MODE='shared'
            WIRELESS_DEFAULT_KEY=0
            WIRELESS_KEY_0="s:{{key0_104_str}}"
            WIRELESS_KEY_1="h:{{key1_104_hex}}"
            WIRELESS_KEY_2="h:{{key2_40_hex}}"
            WIRELESS_KEY_3="s:{{key3_40_str}}"
        ),
        q(
            STARTMODE='auto'
            BOOTPROTO='dhcp'

            WIRELESS_ESSID='{{ssid}}'
            WIRELESS_AUTH_MODE='sharedkey'
            WIRELESS_DEFAULT_KEY=0
            WIRELESS_KEY_0="{{key0_104_hex2}}"
            WIRELESS_KEY_1="h:{{key1_104_hex}}"
            WIRELESS_KEY_2="h:{{key2_40_hex}}"
            WIRELESS_KEY_3="{{key3_40_hex2}}"
        ),
        q(
            STARTMODE='auto'
            BOOTPROTO='dhcp'

            WIRELESS_ESSID='{{ssid}}'
            WIRELESS_AUTH_MODE='restricted'
            WIRELESS_DEFAULT_KEY=1
            WIRELESS_KEY_0="{{key0_104_hex2}}"
            WIRELESS_KEY_1="h:{{key1_104_hex}}"
            WIRELESS_KEY_2="h:{{key2_40_hex}}"
            WIRELESS_KEY_3="h:{{key3_40_hex}}"
        ),
        q(
            STARTMODE='auto'
            BOOTPROTO='dhcp'

            WIRELESS_ESSID='{{ssid}}'
            WIRELESS_AUTH_MODE='shared'
            WIRELESS_DEFAULT_KEY=2
            WIRELESS_KEY_0="{{key0_104_hex2}}"
            WIRELESS_KEY_1="h:{{key1_104_hex}}"
            WIRELESS_KEY_2="h:{{key2_40_hex}}"
            WIRELESS_KEY_3="{{key3_40_hex2}}"
        ),
        q(
            STARTMODE='auto'
            BOOTPROTO='dhcp'

            WIRELESS_ESSID='{{ssid}}'
            WIRELESS_AUTH_MODE='shared'
            WIRELESS_DEFAULT_KEY=3
            WIRELESS_KEY_0="{{key0_104_hex2}}"
            WIRELESS_KEY_1="h:{{key1_104_hex}}"
            WIRELESS_KEY_2="h:{{key2_40_hex}}"
            WIRELESS_KEY_3="{{key3_40_hex}}"
        )
] };

sub run {
    my ($self, @args) = @_;

    if (!$self->hostapd_can_wep()) {
        record_info('SKIP',
            'Skip test, cause installed hostapd does not support WEP',
            result => 'softfail');
        $self->result('skip');
        return;
    }
    $self->SUPER::run(@args);
}

1;
