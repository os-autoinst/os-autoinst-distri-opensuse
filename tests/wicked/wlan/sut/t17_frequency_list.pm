# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Create two accesspoints with the same SSID but different channels.
#   The client is forced to connect to one or the other AP by defining the
#   WIRELESS_FREQUENCY_LIST accordingly.
#   After each `wicked ifup wlanX` the connection between the AP and Client
#   is checked.
#
# Maintainer: cfamullaconrad@suse.com


use Mojo::Base 'wicked::wlan';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(script_retry script_output_retry);

has wicked_version => '>=0.6.76';

has ssid => 'Multiband SSID';
has psk => 'aun5AhCo';

has hostapd_conf => q(
    ctrl_interface=/var/run/hostapd
    interface={{ref_ifc}}
    driver=nl80211
    country_code=DE
    channel=1
    # freqlist=2412
    hw_mode=g
    ieee80211n=1

    ssid={{ssid}}
    wpa=3
    wpa_key_mgmt=WPA-PSK
    wpa_pairwise=TKIP CCMP
    wpa_passphrase={{psk}}
);
has hostapd_conf2 => q(
    ctrl_interface=/var/run/hostapd
    interface={{ref_ifc2}}
    driver=nl80211
    country_code=DE
    channel=36
    # freqlist=5180
    hw_mode=a
    ieee80211n=1

    ssid={{ssid}}
    wpa=3
    wpa_key_mgmt=WPA-PSK
    wpa_pairwise=TKIP CCMP
    wpa_passphrase={{psk}}
);

has ifcfg_wlan_24 => sub { [
        q(
        BOOTPROTO='dhcp'
        STARTMODE='auto'

        WIRELESS_ESSID='{{ssid}}'
        WIRELESS_WPA_PSK='{{psk}}'
        WIRELESS_FREQUENCY_LIST='2412'
        ),
        q(
        BOOTPROTO='dhcp'
        STARTMODE='auto'

        WIRELESS_ESSID='{{ssid}}'
        WIRELESS_WPA_PSK='{{psk}}'
        WIRELESS_FREQUENCY_LIST='2.4GHz'
        ),
        q(
        BOOTPROTO='dhcp'
        STARTMODE='auto'

        WIRELESS_ESSID='{{ssid}}'
        WIRELESS_WPA_PSK='{{psk}}'
        WIRELESS_FREQUENCY_LIST='2,4GHz'
        ),
        q(
        BOOTPROTO='dhcp'
        STARTMODE='auto'

        WIRELESS_ESSID='{{ssid}}'
        WIRELESS_WPA_PSK='{{psk}}'
        WIRELESS_FREQUENCY_LIST='2.4GHz 5220'
        ),
        q(
        BOOTPROTO='dhcp'
        STARTMODE='auto'

        WIRELESS_ESSID='{{ssid}}'
        WIRELESS_WPA_PSK='{{psk}}'
        WIRELESS_FREQUENCY_LIST='2412 2.4GHz 5220'
        ),
        q(
        BOOTPROTO='dhcp'
        STARTMODE='auto'

        WIRELESS_ESSID='{{ssid}}'
        WIRELESS_WPA_PSK='{{psk}}'
        WIRELESS_FREQUENCY_LIST='2437 5220 2412'
        )
] };

has ifcfg_wlan_5 => sub { [
        q(
        BOOTPROTO='dhcp'
        STARTMODE='auto'

        WIRELESS_ESSID='{{ssid}}'
        WIRELESS_WPA_PSK='{{psk}}'
        WIRELESS_FREQUENCY_LIST='5180'
        ),
        q(
        BOOTPROTO='dhcp'
        STARTMODE='auto'

        WIRELESS_ESSID='{{ssid}}'
        WIRELESS_WPA_PSK='{{psk}}'
        WIRELESS_FREQUENCY_LIST='5GHz'
        ),
        q(
        BOOTPROTO='dhcp'
        STARTMODE='auto'

        WIRELESS_ESSID='{{ssid}}'
        WIRELESS_WPA_PSK='{{psk}}'
        WIRELESS_FREQUENCY_LIST='5GHz 2437'
        ),
        q(
        BOOTPROTO='dhcp'
        STARTMODE='auto'

        WIRELESS_ESSID='{{ssid}}'
        WIRELESS_WPA_PSK='{{psk}}'
        WIRELESS_FREQUENCY_LIST='5180 5GHz 2437'
        ),
        q(
        BOOTPROTO='dhcp'
        STARTMODE='auto'

        WIRELESS_ESSID='{{ssid}}'
        WIRELESS_WPA_PSK='{{psk}}'
        WIRELESS_FREQUENCY_LIST='5180 5220 2437'
        ),
] };


sub run {
    my $self = shift;
    my $WAIT_SECONDS = get_var("WICKED_WAIT_SECONDS", 70);

    select_serial_terminal;
    return if ($self->skip_by_wicked_version());
    return if ($self->skip_by_supported_key_mgmt());
    return if ($self->skip_by_wpa_supplicant_version());

    $self->setup_ref();

    # setup ref2
    $self->netns_exec('ip addr add dev ' . $self->ref_ifc2() . ' ' . $self->ref_ip(bss => 1, netmask => 1));
    $self->restart_dhcp_server(ref_ifc => $self->ref_ifc2(), bss => 1) if ($self->use_dhcp());

    # start hostapd
    $self->hostapd_start($self->hostapd_conf());
    $self->hostapd_start($self->hostapd_conf2(), name => 'hostapd.2');

    for my $ifcfg_wlan (wicked::wlan::__as_config_array($self->ifcfg_wlan_24())) {
        $self->write_cfg('/etc/sysconfig/network/ifcfg-' . $self->sut_ifc, $ifcfg_wlan->{config});
        $self->wicked_command('ifup', $self->sut_ifc);
        $self->wicked_command('ifstatus --verbose ', $self->sut_ifc);

        # check
        $self->assert_sta_connected(ref_ifc => $self->ref_ifc());
        $self->assert_connection(ref_ifc => $self->ref_ifc(), timeout => $WAIT_SECONDS);
    }

    for my $ifcfg_wlan (wicked::wlan::__as_config_array($self->ifcfg_wlan_5())) {
        $self->write_cfg('/etc/sysconfig/network/ifcfg-' . $self->sut_ifc, $ifcfg_wlan->{config});
        $self->wicked_command('ifup', $self->sut_ifc);
        $self->wicked_command('ifstatus --verbose ', $self->sut_ifc);

        # check
        $self->assert_sta_connected(ref_ifc => $self->ref_ifc2());
        $self->assert_connection(bss => 1, ref_ifc => $self->ref_ifc2(), timeout => $WAIT_SECONDS);
    }

    # stop hostapd
    $self->hostapd_kill();
    $self->hostapd_kill(name => 'hostapd.2');
}

1;
