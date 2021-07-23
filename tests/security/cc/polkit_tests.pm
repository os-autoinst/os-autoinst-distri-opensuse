# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Run 'polkit-tests' test case of 'audit-test' test suite
# Maintainer: Liu Xiaojing <xiaojing.liu@suse.com>
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
    my $result = compare_run_log('polkit_tests');
    $self->result($result);
}

sub test_flags {
    return {no_rollback => 1};
}

1;
