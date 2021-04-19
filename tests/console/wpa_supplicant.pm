# SUSE's openQA tests
#
# Copyright © 2020-2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: wpa_supplicant hostapd iw dnsmasq unzip
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

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    zypper_call 'in wpa_supplicant hostapd iw dnsmasq unzip';
    assert_script_run 'cd $(mktemp -d)';
    assert_script_run('curl -L -s ' . data_url('wpa_supplicant') . ' | cpio --make-directories --extract && cd data');
    assert_script_run('bash -x ./wpa_supplicant_test.sh 2>&1 | tee wpa-supplicant_test.txt', timeout => 600);
}

sub post_fail_hook {
    # Upload logs if present
    upload_logs("wicked.log")              if (script_run("stat wicked.log") == 0);
    upload_logs("wpa-supplicant_test.txt") if (script_run("stat wpa-supplicant_test.txt") == 0);
}

1;
