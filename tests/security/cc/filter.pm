# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run 'filter' test case of 'audit-test' test suite
# Maintainer: rfan1 <richard.fan@suse.com>, Liu Xiaojing <xiaojing.liu@suse.com>
# Tags: poo#95464

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use audit_test qw(run_testcase compare_run_log);

sub run {
    my ($self) = shift;

    select_console 'root-console';

    run_testcase('filter', (make => 1, timeout => 180));

    # Compare current test results with baseline
    my $result = compare_run_log('filter');
    $self->result($result);
}

1;
