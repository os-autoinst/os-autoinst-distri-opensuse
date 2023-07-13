# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test WiFi setup with different SSID format strings
#          * Hex format
#          * UTF-8
#          * Ocal format
#          * Escape sequences
#
# Maintainer: cfamullaconrad@suse.com


use Mojo::Base 'wicked::wlan';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(random_string);
use Encode qw/encode_utf8/;

has wicked_version => '>=0.6.66';

has ssid_0 => '00010203';
has ssid_0_ifcfg => '\x00\x01\x02\x03';
has ssid_1 => '426cc3bc74657a65697400e585a8e79b9be69c9f';
has ssid_1_ifcfg => 'Blütezeit\x00全盛期';
has ssid_2 => '090a0d1b5c225b5d7b7d2f';
has ssid_2_ifcfg => '\t\n\r\e\\\\\"[]{}/';
has ssid_3 => '004101410241034107410831';
has ssid_3_ifcfg => '\0A\1A\02A\003A\007A\0101';

has hostapd_conf => q(
    ctrl_interface=/var/run/hostapd
    interface={{ref_ifc}}
    driver=nl80211
    country_code=DE
    channel=1
    hw_mode=g
    ieee80211n=1

    ssid2={{ssid_0}}

    bss={{ref_bss1}}
    ctrl_interface=/var/run/hostapd
    ssid2={{ssid_1}}
 
    bss={{ref_bss2}}
    ctrl_interface=/var/run/hostapd
    ssid2={{ssid_2}}
   
    bss={{ref_bss3}}
    ctrl_interface=/var/run/hostapd
    ssid2={{ssid_3}}
  );


has ifcfg_wlan => sub { [
        q(
            BOOTPROTO='dhcp'
            STARTMODE='auto'
            WIRELESS_ESSID='{{ssid_0_ifcfg}}'
        ),
        q(
            BOOTPROTO='dhcp'
            STARTMODE='auto'
            WIRELESS_ESSID='{{ssid_1_ifcfg}}'
        ),
        q(
            BOOTPROTO='dhcp'
            STARTMODE='auto'
            WIRELESS_ESSID='{{ssid_2_ifcfg}}'
        ),
        q(
            BOOTPROTO='dhcp'
            STARTMODE='auto'
            WIRELESS_ESSID='{{ssid_3_ifcfg}}'
        ),
] };



sub run {
    my $self = shift;
    my $WAIT_SECONDS = get_var("WICKED_WAIT_SECONDS", 70);

    select_serial_terminal;
    return if ($self->skip_by_wicked_version());

    $self->setup_ref();

    # Start hostapd
    $self->hostapd_start($self->hostapd_conf());

    for my $bss (qw(0 1 2 3)) {
        my $ssid = 'ssid_' . $bss . '_ifcfg';
        record_info('SSID', encode_utf8($self->$ssid));

        $self->write_cfg('/etc/sysconfig/network/ifcfg-' . $self->sut_ifc, $self->ifcfg_wlan()->[$bss], encode_base64 => 1);
        $self->wicked_command('ifup', $self->sut_ifc);

        record_info('SHOW-XML', script_output('wicked show-xml ' . $self->sut_ifc()));
        record_info('SHOW-CONFIG', script_output('wicked show-config ' . $self->sut_ifc()));

        $self->assert_sta_connected(bss => $bss, timeout => $WAIT_SECONDS);
        $self->assert_connection(timeout => $WAIT_SECONDS, bss => $bss);
        $self->wicked_command('ifstatus --verbose', $self->sut_ifc);
        $self->wicked_command('ifdown', $self->sut_ifc);
    }
}

1;
