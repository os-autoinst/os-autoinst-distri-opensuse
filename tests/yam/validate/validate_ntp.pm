# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate the ntp servers and chronyc tracking by checking
# - NTP servers are present in /etc/chrony.d/99-installer.conf
# - The system is actively synchronized to an external time source
#   rather than being unsynchronized or relying on its own local clock

# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use scheduler qw(get_test_suite_data);

sub run {
    my $test_data = get_test_suite_data();
    select_console 'root-console';

    my $chrony_config = '/etc/chrony.d/99-installer.conf';
    assert_script_run("cat $chrony_config");
    assert_script_run("grep '$_' $chrony_config") foreach @{$test_data->{ntp_servers}};

    assert_script_run('chronyc waitsync 24 0 0 5');

    my $tracking_output = script_output('chronyc -c tracking');
    my @fields = split(/,/, $tracking_output);

    if (@fields >= 2) {
        my $ref_id = $fields[1];
        # 00000000 means unsynced/error; 1F1F0101 means local directive active
        if ($ref_id eq '00000000' || $ref_id eq '1F1F0101') {
            die "NTP synchronization failed: Invalid Reference ID ($ref_id)";
        }
    } else {
        die "Failed to parse Reference ID from 'chronyc -c tracking' output: $tracking_output";
    }
}

1;
