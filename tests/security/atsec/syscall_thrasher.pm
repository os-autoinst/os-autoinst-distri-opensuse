# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run 'Syscall_thrasher' test case of ATSec test suite
# Maintainer: QE Security <none@suse.de>
# Tags: poo#109774

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = shift;

    select_console 'root-console';

    # Complile thrash.c
    my $exe_file = 'thrash';
    assert_script_run('cd /usr/local/atsec');
    assert_script_run("gcc -o $exe_file thrash.c");

    # Change the permission of test script because we need to run it as non-root
    assert_script_run("chmod 755 $exe_file");

    # The test needs to run by non-root
    select_console 'user-console';

    # Prepare the test directory
    my $test_dir = 'test_syscall_thrasher';
    assert_script_run("mkdir -p $test_dir");

    # Copy the executable file to test directory
    assert_script_run("cp /usr/local/atsec/$exe_file $test_dir/");

    # Run the test
    assert_script_run("cd $test_dir");
    assert_script_run("./$exe_file", timeout => 1200);
    assert_script_run('ls');
}

sub test_flags {
    return {always_rollback => 1};
}

1;
