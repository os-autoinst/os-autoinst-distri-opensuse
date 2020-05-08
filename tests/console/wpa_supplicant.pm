# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test wpa_supplicant on virtual wifi interfaces
#  - Setup virtual wlan interfaces
#  - Wifi access point:
#    - Isolate wlan0 in separate network namespace
#    - Create access point using dnsmasq and hostapd on wlan0
#  - For the client (actual wpa_supplicant test)
#    - Scan for virtual wifi networks
#    - Connect to open network
#    - Ping access point (static IP-addresses)
#    - Connect to WPA2 network
#    - Ping access point (static IP-addresses)
#    - Unassign static IP
#    - Get new IP address using dhcp with wicked
#    - Ping access point (now dhcp IP-address)
# Maintainer: Felix Niederwanger <felix.niederwanger@suse.de>

use base 'consoletest';
use testapi;
use strict;
use warnings;
use utils;
use registration qw(cleanup_registration register_product add_suseconnect_product get_addon_fullname remove_suseconnect_product);
use version_utils "is_sle";

sub run {
    my $self = shift;
    $self->select_serial_terminal;
    # packagehub module needed for dependencies (hostapd)
    if (is_sle) {
        record_info('Install-Info', 'Adding package hub repository');
        cleanup_registration;
        register_product;
        add_suseconnect_product(get_addon_fullname('phub'));
    }
    zypper_call 'in wpa_supplicant hostapd iw dnsmasq unzip';
    assert_script_run 'cd /var/tmp';
    assert_script_run 'curl -v -o wpa_supplicant-test.zip ' . data_url('wpa_supplicant/wpa_supplicant-test.zip');
    assert_script_run 'unzip wpa_supplicant-test.zip';
    record_info('Info', 'Running wpa_supplicant_test.sh');
    assert_script_run('bash -x ./wpa_supplicant_test.sh', timeout => 600);
    # unregister SDK
    if (is_sle && !main_common::is_updates_tests()) {
        remove_suseconnect_product(get_addon_fullname('phub'));
        record_info('Install-Info', 'Removed package hub repository');
    }
}

1;
