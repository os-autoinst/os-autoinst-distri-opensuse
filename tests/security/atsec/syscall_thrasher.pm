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

my $log_file = '/tmp/syscalls_output.log';

sub run {
    my ($self) = shift;

    select_console 'root-console';

    my $exe_file = 'thrash';
    assert_script_run('cd /usr/local/atsec');
    assert_script_run("gcc -o $exe_file thrash.c");

    assert_script_run("chmod 755 $exe_file");

    # The test needs to run by non-root
    select_console 'user-console';

    my $test_dir = 'test_syscall_thrasher';
    assert_script_run("mkdir -p $test_dir");

    assert_script_run("cp /usr/local/atsec/$exe_file $test_dir/");

    assert_script_run("cd $test_dir");
    assert_script_run("./$exe_file >> $log_file", timeout => 900);
    upload_logs("$log_file");
}

sub test_flags {
    return {always_rollback => 1};
}

sub post_fail_hook {
    my ($self) = @_;
    upload_logs("$log_file");
    $self->SUPER::post_fail_hook;
}

1;
