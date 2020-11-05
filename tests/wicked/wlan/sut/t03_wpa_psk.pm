# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Wifi preparation
# Maintainer: cfamullaconrad@suse.com


use Mojo::Base 'wickedbase';
use testapi;
use utils qw(zypper_call);
use registration qw(add_suseconnect_product);
use serial_terminal;

sub run {
    my $self = shift;

    $self->select_serial_terminal;
    assert_script_run('ip netns exec wifi_master iw dev');
    assert_script_run('ip netns exec wifi_master ip addr add dev wlan0 10.6.6.1/24');

    script_output(<<END_OF_STRING);
cat > hostapd.conf << 'EOT'
ctrl_interface=/var/run/hostapd
interface=wlan0
driver=nl80211
country_code=DE
ssid=Virtual Wifi
channel=0
hw_mode=b
wpa=3
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP CCMP
wpa_passphrase=TopSecretWifiPassphrase
auth_algs=3
beacon_int=100
EOT
END_OF_STRING
    assert_script_run('ip netns exec wifi_master hostapd -B hostapd.conf');


    assert_script_run('iw dev');

    script_output(<<END_OF_STRING);
cat > /etc/sysconfig/network/ifcfg-wlan1 << 'EOT'
STARTMODE='auto'

BOOTPROTO='static'
IPADDR='10.6.6.2'
NETMASK='255.255.255.0'

WIRELESS_MODE='Managed'
WIRELESS_AUTH_MODE='psk'
WIRELESS_ESSID='Virtual Wifi'
WIRELESS_WPA_PSK='TopSecretWifiPassphrase'
EOT
END_OF_STRING

    $self->wicked_command('ifup', 'wlan1');

    assert_script_run('ip netns exec wifi_master hostapd_cli all_sta');
}

sub test_flags {
    return {always_rollback => 1};
}

1;
