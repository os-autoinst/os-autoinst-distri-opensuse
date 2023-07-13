# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run 'syscalls' test case of 'audit-test' test suite
# Maintainer: QE Security <none@suse.de>
# Tags: poo#94684, poo#106736

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use audit_test qw(run_testcase compare_run_log rerun_fail_cases);

sub run {
    my ($self) = shift;

    select_console "root-console";

    if (my $pprofile = get_var('PPROFILE')) {
        assert_script_run("export PPROFILE=$pprofile");
    }

    # Run test case
    run_testcase('syscalls', (make => 1, timeout => 720));

    # Rerun randomly fail cases
    rerun_fail_cases();

    # Compare current test results with baseline
    my $result = compare_run_log('syscalls');
    $self->result($result);
}

sub test_flags {
    return {no_rollback => 1};
}

1;
