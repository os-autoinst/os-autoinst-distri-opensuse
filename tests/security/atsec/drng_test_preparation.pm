# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run 'DRNG test preparation' test case of ATSec test suite
# Maintainer: xiaojing.liu <xiaojing.liu@suse.com>
# Tags: poo#108485

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use atsec_test;

sub run {
    my ($self) = shift;

    select_console 'root-console';

    # Install the required packages
    zypper_call('in libopenssl-devel libgcrypt-devel');

    my $test_dir = '/root/eval/drng';
    # Complile gather_random_data
    my $exe_file = 'gather_random_data';
    assert_script_run("cd $atsec_test::code_dir");
    assert_script_run("gcc -o $exe_file -lcrypto -lssl -lgcrypt gather_random_data.c");

    # Prepare the test directory
    assert_script_run("mkdir -p $test_dir");

    # Copy the executable file to test directory
    assert_script_run("cp $exe_file $test_dir/");

    # Run the test
    assert_script_run("cd $test_dir");
    assert_script_run("./$exe_file 2");

    # Check result
    # We need to filter 'total ' and gather_random_data from the results of 'ls -l',
    # then check if there are only 3 files are generated (As expected).
    my $result = script_output("ls -l | grep -v \"total\" | grep -v \"$exe_file\"");
    my @lines = split(/\n/, $result);
    record_info('ERROR', "Others files are generated\n$result", result => 'fail') if (scalar(@lines) != 3);

    foreach my $line (@lines) {
        my @items = split(/\s/, $line);
        my $file_size = $items[4];
        my $file_name = $items[-1];

        # Skip gather_random_data
        next if ($file_name eq $exe_file);

        # The size of file should be 5M
        if (int($file_size) != 5242880) {
            record_info('ERROR', "The size of $file_name isn't 5M:\n $file_size $file_name", result => 'fail');
            $self->result('fail');
        }
    }
}

sub test_flags {
    return {always_rollback => 1};
}

1;
