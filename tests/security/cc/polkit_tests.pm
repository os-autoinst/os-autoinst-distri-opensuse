# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run 'polkit-tests' test case of 'audit-test' test suite
# Maintainer: QE Security <none@suse.de>
# Tags: poo#95762

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use audit_test qw(run_testcase compare_run_log);

sub run {
    my ($self) = shift;

    select_console 'root-console';

    # PASSWD is needed by polkit_success
    script_run("export PASSWD=$testapi::password");
    run_testcase('polkit-tests');

    # Compare current test results with baseline
    my $result = compare_run_log('polkit-tests');
    $self->result($result);
}

sub test_flags {
    return {no_rollback => 1};
}

1;
