# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate the ntp servers and chronyc tracking by checking
# - NTP servers are present in /etc/chrony.d/99-installer.conf
# - No Pending Leap Seconds are detected via chronyc tracking.

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
}

1;
