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
use audit_test qw(run_testcase compare_run_log rerun_fail_cases);

sub run {
    my ($self) = shift;

    select_console 'root-console';

    run_testcase('filter', (make => 1, timeout => 180));

    # Rerun randomly fail cases
    rerun_fail_cases();

    # Compare current test results with baseline
    my $result = compare_run_log('filter');
    $self->result($result);
}

1;
