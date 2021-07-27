# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Run 'ip+eb-tables' test case of 'audit-test' test suite
# Maintainer: llzhao <llzhao@suse.com>
# Tags: poo#96049

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use audit_test qw(run_testcase compare_run_log);

sub run {
    my ($self) = shift;

    select_console 'root-console';

    # Run test case
    run_testcase('ip+eb-tables', timeout => 300);

    # Compare current test results with baseline
    my $result = compare_run_log('ip_eb_tables');
    $self->result($result);
}

sub test_flags {
    return {always_rollback => 1};
}

1;
