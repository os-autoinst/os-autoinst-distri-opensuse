# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test WiFi setup with wicked (WPA-PSK with DHCP)
#          If a connection is established, the AP will went down and a other
#          SSID appear. Check if the wpa_supplicant also connect to the new one.
#
#
# Maintainer: cfamullaconrad@suse.com


use Mojo::Base 'wicked::wlan';
use testapi;

has wicked_version => '>=0.6.66';
has ssid           => 'Virtual WiFi PSK Secured';
has psk            => 'TopSecretWifiPassphrase!';

has ssid_2 => 'Second WiFi PSK Secured';
has psk_2  => 'TopSecret2222!';

has hostapd_conf => q(
    ctrl_interface=/var/run/hostapd
    interface={{ref_ifc}}
    driver=nl80211
    country_code=DE
    channel=1
    hw_mode=g
    ieee80211n=1

    ssid={{ssid}}
    wpa=2
    wpa_key_mgmt=WPA-PSK
    wpa_pairwise=CCMP
    wpa_passphrase={{psk}}
);

has hostapd_conf_2 => q(
    ctrl_interface=/var/run/hostapd
    interface={{ref_ifc}}
    driver=nl80211
    country_code=DE
    channel=1
    hw_mode=g
    ieee80211n=1

    ssid={{ssid_2}}
    wpa=3
    wpa_key_mgmt=WPA-PSK
    wpa_pairwise=TKIP CCMP
    wpa_passphrase={{psk_2}}
);


has ifcfg_wlan => q(
    BOOTPROTO='dhcp'
    STARTMODE='auto'

    WIRELESS_ESSID='{{ssid}}'
    WIRELESS_WPA_PSK='{{psk}}'

    WIRELESS_ESSID_1='{{ssid_2}}'
    WIRELESS_WPA_PSK_1='{{psk_2}}'
);

sub run {
    my $self         = shift;
    my $WAIT_SECONDS = get_var("WICKED_WAIT_SECONDS", 70);
    $self->select_serial_terminal;
    return if ($self->skip_by_wicked_version());


    $self->setup_ref();

    # Start hostapd
    $self->write_cfg('/tmp/hostapd.conf', $self->hostapd_conf);
    $self->netns_exec('hostapd -P /tmp/hostapd.pid -B /tmp/hostapd.conf');

    # Setup sut
    $self->write_cfg('/etc/sysconfig/network/ifcfg-' . $self->sut_ifc, $self->ifcfg_wlan);
    $self->wicked_command('ifup', $self->sut_ifc);

    # Check
    $self->assert_sta_connected();
    $self->assert_connection();
    $self->wicked_command('ifstatus --verbose', $self->sut_ifc);

    # Reconfigure hostapd
    assert_script_run('kill $(cat /tmp/hostapd.pid)');
    $self->write_cfg('/tmp/hostapd.conf', $self->hostapd_conf_2);
    $self->netns_exec('hostapd -P /tmp/hostapd.pid -B /tmp/hostapd.conf');

    # Check after reconnect
    $self->assert_sta_connected(timeout => $WAIT_SECONDS);
    $self->assert_connection(timeout => $WAIT_SECONDS);
    $self->wicked_command('ifstatus --verbose', $self->sut_ifc);
}

1;
