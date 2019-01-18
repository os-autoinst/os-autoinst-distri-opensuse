# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Verify firewall configuration after installation using ay profile
# Maintainer: Rodion Iafarov <riafarov@suse.com>

use base 'basetest';
use strict;
use warnings;
use testapi;
use utils 'systemctl';

sub run {
    # Verify that service is active
    systemctl 'is-active firewalld.service';
    # Verify firewalld is running, returns 0 code only is running
    assert_script_run('firewall-cmd --state');
    my $errors = '';
    # Verify services configured for external zone
    my $zone_config = script_output('firewall-offline-cmd --list-services --zone=public');
    $errors .= "services are not configured for public zone, expected apache2 apache2-ssl, got: $zone_config\n" unless $zone_config =~ /apache2 apache2-ssl/;
    # Verify ports configured for external zone
    $zone_config = script_output('firewall-offline-cmd --list-ports --zone=public');
    $errors .= "ports are not configured for public zone, expected 8080/tcp 9090/udp, got: $zone_config\n" unless $zone_config =~ m|8080/tcp 9090/udp|;
    # Verify services configured for internal zone
    $zone_config = script_output('firewall-offline-cmd --list-services --zone=trusted');
    $errors .= "services are not configured for trusted zone, expected ssh, got: $zone_config\n" unless $zone_config =~ /ssh/;
    # Verify ports configured for internal zone
    $zone_config = script_output('firewall-offline-cmd --list-ports --zone=trusted');
    $errors .= "ports are not configured for trusted zone, expected 22/tcp 5353/udp, got: $zone_config\n" unless $zone_config =~ m|22/tcp 5353/udp|;

    # Fail the test if any error
    die "Test failed:\n$errors" if $errors;
}

1;
