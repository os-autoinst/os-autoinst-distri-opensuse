# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run 'libpam' test case of 'audit-test' test suite
# Maintainer: QE Security <none@suse.de>
# Tags: poo#95911

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use audit_test qw(run_testcase compare_run_log);

sub run {
    my ($self) = shift;

    select_console 'root-console';

    # PASSWD is needed by test case 'ssh04'
    script_run("export PASSWD=$testapi::password");

    run_testcase('libpam', (make => 1, timeout => 900));

    # Compare current test results with baseline
    my $result = compare_run_log('libpam');
    $self->result($result);
}

1;
