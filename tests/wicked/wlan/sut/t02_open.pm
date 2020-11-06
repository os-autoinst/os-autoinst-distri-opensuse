# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
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

my $hostapd_conf = q(
    ctrl_interface=/var/run/hostapd
    interface={{ref_ifc}}
    driver=nl80211
    country_code=DE
    ssid={{ssid}}
    channel=0
    hw_mode=g
);

my $ifcfg_wlan = q(
    STARTMODE='auto'
    BOOTPROTO='dhcp'
    WIRELESS_MODE='Managed'
    WIRELESS_ESSID='{{ssid}}'
);

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    # Setup ref
    $self->netns_exec('ip addr add dev wlan0 ' . $self->ref_ip . '/24');
    $self->restart_DHCP_server();
    $self->write_cfg('hostapd.conf', $hostapd_conf);
    $self->netns_exec('hostapd -B hostapd.conf');

    # Setup sut
    $self->write_cfg('/etc/sysconfig/network/ifcfg-' . $self->sut_ifc, $ifcfg_wlan);
    $self->wicked_command('ifup', $self->sut_ifc);

    # Check
    $self->assert_sta_connected();
    $self->assert_connection();
}

1;
