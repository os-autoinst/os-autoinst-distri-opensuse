# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

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
#   - Get new IP address using dhcp with wicked
#    - Ping access point (now dhcp IP-address)
# Maintainer: Felix Niederwanger <felix.niederwanger@suse.de>

use base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use strict;
use warnings;
use utils;

sub run {
    my $self = shift;
    select_serial_terminal;

    zypper_call 'in wpa_supplicant hostapd iw dnsmasq unzip dhcp-client';
    assert_script_run 'cd $(mktemp -d)';
    assert_script_run('curl -L -s ' . data_url('wpa_supplicant') . ' | cpio --make-directories --extract && cd data');
    $self->adopt_apparmor;
    script_run('./wpa_supplicant_test.sh 2>&1 | tee wpa-supplicant_test.txt', timeout => 600);
    validate_script_output("cat wpa-supplicant_test.txt", qr/WPA_SUPPLICANT_TEST: PASSED/);
}

sub adopt_apparmor {
    if (script_output('systemctl is-active apparmor', proceed_on_failure => 1) eq 'active') {
        assert_script_run('echo "# adopt AppArmor"');
        assert_script_run(q(test ! -e /etc/apparmor.d/usr.sbin.hostapd ||  sed -i "s|^}$|  $PWD/\hostapd.conf r,\n}|g"  /etc/apparmor.d/usr.sbin.hostapd));
        systemctl 'reload apparmor';
    }
}

sub post_fail_hook {
    # Upload logs if present
    upload_logs("wicked.log") if (script_run("stat wicked.log") == 0);
    upload_logs("wpa-supplicant_test.txt") if (script_run("stat wpa-supplicant_test.txt") == 0);
    upload_logs("hostapd.log") if (script_run("stat hostapd.log") == 0);
    upload_logs("wpa_supplicant.log") if (script_run("stat wpa_supplicant.log") == 0);
}

1;
