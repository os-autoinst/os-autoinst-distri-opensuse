# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run 'audit-trail-protection' test case of 'audit-test' test suite
# Maintainer: QE Security <none@suse.de>
# Tags: poo#94447

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use audit_test qw(run_testcase compare_run_log);

sub run {
    my ($self) = shift;

    select_console 'root-console';

    run_testcase('audit-trail-protection', (make => 1));

    # Compare current test results with baseline
    my $result = compare_run_log('audit-trail-protection');
    $self->result($result);
}

1;
