# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate the ntp servers and chronyc tracking by checking
# - NTP serveres were present in /etc/chrony.d/99-installer.conf
# - chronyc tracking was working
# - Time is verified and synchronization status is Normal

# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use scheduler 'get_test_suite_data';

sub run {

    my $test_data = get_test_suite_data();
    select_console 'root-console';

    record_info('99-installer.conf', script_output('cat /etc/chrony.d/99-installer.conf'));

    foreach my $ntp (@{$test_data->{ntp_servers}}) {
        assert_script_run("grep '$ntp' /etc/chrony.d/99-installer.conf");
    }

    assert_script_run('chronyc tracking');
    my $tracking_output = script_output('chronyc tracking');
    record_info('chronyc tracking', $tracking_output);

    if ($tracking_output =~ /Leap status\s*:\s*(\w+)/) {
        die "Chrony tracking failed, Expected Leap status 'Normal', but got '$1'." if $1 ne 'Normal';
    } else {
        die "Could not get Leap status from chronyc tracking.";
    }
}

1;
