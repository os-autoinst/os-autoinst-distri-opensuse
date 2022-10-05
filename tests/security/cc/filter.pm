# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run 'filter' test case of 'audit-test' test suite
# Maintainer: QE Security <none@suse.de>
# Tags: poo#95464, poo#106735

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use Utils::Architectures;
use version_utils;
use audit_test qw(run_testcase compare_run_log rerun_fail_cases);

sub run {
    my ($self) = shift;

    select_console 'root-console';

    if (is_sle('=15-sp3')) {
        my $test_dir = $audit_test::test_dir;
        assert_script_run("sed -i 's/+ class_exec//' $test_dir/audit-test/filter/run.conf") if !is_aarch64;
        assert_script_run("sed -i 's/+ class_attr//' $test_dir/audit-test/filter/run.conf");
        record_soft_failure("poo#116683 - class_exec and class_attr fail on 15-SP3");
    }

    run_testcase('filter', (make => 1, timeout => 180));

    # Rerun randomly fail cases
    rerun_fail_cases();

    # Compare current test results with baseline
    my $result = compare_run_log('filter');
    $self->result($result);
}

1;
