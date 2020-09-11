# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Test module to verify that actual default target corresponds to the
# expected one.
# Maintainer: Oleksandr Orlov <oorlov@suse.de>

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
