# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Run 'audit-trail-protection' test case of 'audit-test' test suite
# Maintainer: rfan1 <richard.fan@suse.com>, Liu Xiaojing <xiaojing.liu@suse.com>
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
    my $result = compare_run_log('audit_trail_protection');
    $self->result($result);
}

1;
