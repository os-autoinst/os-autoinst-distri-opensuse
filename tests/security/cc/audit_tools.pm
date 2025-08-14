# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run 'audit-tools' test case of 'audit-test' test suite
# Maintainer: QE Security <none@suse.de>
# Tags: poo#94450, poo#106816

use base 'consoletest';
use testapi;
use utils;
use version_utils 'is_sle';
use audit_test qw(run_testcase compare_run_log rerun_fail_cases);

sub run {
    my ($self) = shift;

    select_console 'root-console';

    # Run test case
    run_testcase('audit-tools');

    # Rerun randomly fail cases
    rerun_fail_cases();

    # Compare current test results with baseline
    my $result = compare_run_log('audit-tools');
    $self->result($result);

    if ($result == 'fail' && is_sle '>=15-SP4') {
        record_soft_failure("bsc#1209910");
        $self->result('ok');
    }
}

sub test_flags {
    return {always_rollback => 1};
}

1;
