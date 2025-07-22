# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run 'misc' test case of 'audit-test' test suite
# Maintainer: QE Security <none@suse.de>
# Tags: poo#95488

use base 'consoletest';
use testapi;
use utils;
use audit_test qw(run_testcase compare_run_log);
use Utils::Architectures qw(is_s390x);

sub run {
    my ($self) = shift;

    reset_consoles if !is_s390x;
    select_console 'root-console';

    # Run test case
    run_testcase('misc', make => 1, timeout => 300);

    # Compare current test results with baseline
    my $result = compare_run_log('misc');
    $self->result($result);
}

sub test_flags {
    return {always_rollback => 1};
}

1;
