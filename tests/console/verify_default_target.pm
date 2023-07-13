# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: systemd
# Summary: Test module to verify that actual default target corresponds to the
# expected one.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use testapi;
use base 'basetest';
use scheduler 'get_test_suite_data';
use Test::Assert 'assert_equals';

my $test_data;

sub run {
    $test_data = get_test_suite_data();

    select_console 'root-console';
    my $actual_default_target = script_output('systemctl get-default');

    record_info('Default target',
        'Verify that actual default target corresponds to the expected one.');
    assert_equals($test_data->{default_target}, $actual_default_target,
        'Default target does not correspond to the expected one.');
}

1;
