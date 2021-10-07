# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Run 'libpam' test case of 'audit-test' test suite
# Maintainer: rfan1 <richard.fan@suse.com>, Liu Xiaojing <xiaojing.liu@suse.com>
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
