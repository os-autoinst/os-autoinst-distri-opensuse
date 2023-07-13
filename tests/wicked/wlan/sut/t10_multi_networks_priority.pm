# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test WiFi setup with wicked (WPA-PSK with DHCP)
#          If a connection is established, the AP will went down and a other
#          SSID appear. Check if the wpa_supplicant also connect to the new one.
#
#
# Maintainer: cfamullaconrad@suse.com


use Mojo::Base 'wicked::wlan';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(script_retry script_output_retry);

has wicked_version => '>=0.6.66';
has ssid => 'First SSID';
has ssid_1 => 'Second SSID';
has ssid_2 => 'Third SSID';
has ssid_3 => 'Fourth SSID';

has psk => 'aun5AhCo';
has psk_1 => 'Eyoh4Woo';
has psk_2 => 'Too9ziew';
has psk_3 => 'thu6Aech';

has hostapd_conf => q(
    ctrl_interface=/var/run/hostapd
    interface={{ref_ifc}}
    driver=nl80211
    country_code=DE
    channel=1
    hw_mode=g
    ieee80211n=1

    ssid={{ssid}}
    wpa_key_mgmt=WPA-PSK
    wpa_pairwise=TKIP CCMP
    wpa_passphrase={{psk}}
    wpa=3

    bss={{ref_bss1}}
    ctrl_interface=/var/run/hostapd
    ssid={{ssid_1}}
    wpa_key_mgmt=WPA-PSK
    wpa_pairwise=TKIP CCMP
    wpa_passphrase={{psk_1}}
    wpa=3

    bss={{ref_bss2}}
    ctrl_interface=/var/run/hostapd
    ssid={{ssid_2}}
    wpa_key_mgmt=WPA-PSK
    wpa_pairwise=TKIP CCMP
    wpa_passphrase={{psk_2}}
    wpa=3

    bss={{ref_bss3}}
    ctrl_interface=/var/run/hostapd
    ssid={{ssid_3}}
    wpa_key_mgmt=WPA-PSK
    wpa_pairwise=TKIP CCMP
    wpa_passphrase={{psk_3}}
    wpa=3
);


has hostapd_conf_2 => q(
    ctrl_interface=/var/run/hostapd
    interface={{ref_ifc}}
    driver=nl80211
    country_code=DE
    channel=1
    hw_mode=g

    ssid={{ssid}}
    wpa_key_mgmt=WPA-PSK
    wpa_pairwise=TKIP CCMP
    wpa_passphrase={{psk}}
    wpa=3

    bss={{ref_bss1}}
    ctrl_interface=/var/run/hostapd
    ssid={{ssid_1}}
    wpa_key_mgmt=WPA-PSK
    wpa_pairwise=TKIP CCMP
    wpa_passphrase={{psk_1}}
    wpa=3

    bss={{ref_bss3}}
    ctrl_interface=/var/run/hostapd
    ssid={{ssid_3}}
    wpa_key_mgmt=WPA-PSK
    wpa_pairwise=TKIP CCMP
    wpa_passphrase={{psk_3}}
    wpa=3
);

has hostapd_conf_3 => q(
    ctrl_interface=/var/run/hostapd
    interface={{ref_ifc}}
    driver=nl80211
    country_code=DE
    channel=1
    hw_mode=g

    ssid={{ssid}}
    wpa_key_mgmt=WPA-PSK
    wpa_pairwise=TKIP CCMP
    wpa_passphrase={{psk}}
    wpa=3

    bss={{ref_bss3}}
    ctrl_interface=/var/run/hostapd
    ssid={{ssid_3}}
    wpa_key_mgmt=WPA-PSK
    wpa_pairwise=TKIP CCMP
    wpa_passphrase={{psk_3}}
    wpa=3
);

has ifcfg_wlan => q(
    BOOTPROTO='dhcp'
    STARTMODE='auto'

    WIRELESS_ESSID='{{ssid}}'
    WIRELESS_WPA_PSK='{{psk}}'

    WIRELESS_ESSID_1='{{ssid_1}}'
    WIRELESS_WPA_PSK_1='{{psk_1}}'
    WIRELESS_PRIORITY_1=5

    WIRELESS_ESSID_2='{{ssid_2}}'
    WIRELESS_WPA_PSK_2='{{psk_2}}'
    WIRELESS_PRIORITY_2=10

    WIRELESS_ESSID_3='{{ssid_3}}'
    WIRELESS_WPA_PSK_3='{{psk_3}}'
);



sub run {
    my $self = shift;
    my $WAIT_SECONDS = get_var("WICKED_WAIT_SECONDS", 70);
    select_serial_terminal;
    return if ($self->skip_by_wicked_version());

    $self->setup_ref();

    # Start hostapd
    $self->hostapd_start($self->hostapd_conf());

    # Setup sut
    $self->write_cfg('/etc/sysconfig/network/ifcfg-' . $self->sut_ifc, $self->ifcfg_wlan);
    $self->wicked_command('ifup', $self->sut_ifc);

    # Check
    # The one with highest prio should be selected
    $self->assert_sta_connected(ref_ifc => $self->ref_bss2);
    $self->assert_connection(timeout => $WAIT_SECONDS, bss => 2);
    $self->wicked_command('ifstatus --verbose', $self->sut_ifc);

    $self->hostapd_kill();
    $self->hostapd_start($self->hostapd_conf_2());

    # Check
    # The one with not highest prio, but available
    $self->assert_sta_connected(ref_ifc => $self->ref_bss1, timeout => $WAIT_SECONDS);
    $self->assert_connection(timeout => $WAIT_SECONDS, bss => 1);
    $self->wicked_command('ifstatus --verbose', $self->sut_ifc);

    my $cmd = "wicked show-xml " . $self->sut_ifc . " | wicked xpath --reference 'object/wireless/current-connection' '%{bssid}'";
    my $last_bss = script_output($cmd);


    $self->hostapd_kill();
    $self->hostapd_start($self->hostapd_conf_3());

    # Check
    # No Prio set the STA should be connected, but we do not care which BSS
    my $bss = $last_bss;
    while ($bss eq $last_bss) {
        $bss = script_output_retry($cmd, delay => 1, retry => $WAIT_SECONDS);
    }

    if ($bss eq $self->get_hw_address($self->ref_ifc)) {
        $bss = 0;
    } else {
        $bss = 3;
    }

    $self->assert_sta_connected(timeout => $WAIT_SECONDS, bss => $bss);
    $self->assert_connection(timeout => $WAIT_SECONDS, bss => $bss);
    $self->wicked_command('ifstatus --verbose', $self->sut_ifc);
}

1;
