# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run 'Permission settings of relevant configuration files' test case of EAL4 test suite
# Maintainer: QE Security <none@suse.de>
# Tags: poo#111518

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use eal4_test;

sub run {
    my ($self) = shift;
    my $test_log = "permission_settings_log.txt";

    select_console 'root-console';

    my $output = script_output('find -L /etc -perm -g+w,o+w');

    # This test is to verify that important configuration files are protected
    # against access by unauthorized users. The result shows files that are softlinks
    # or the random device is allowed exception to the intial result expectation.
    script_run('printf "# This test is to verify that important configuration files are protected\n" >> ' . $test_log . '');
    script_run('printf "# against access by unauthorized users. The result shows files that are softlinks\n" >> ' . $test_log . '');
    script_run('printf "# or the random device is allowed exception to the intial result expectation.\n\n" >> ' . $test_log . '');

    script_run('printf "find -L /etc -perm -g+w,o+w\n" >> ' . $test_log . '');
    script_run('printf "' . $output . '\n" >> ' . $test_log . '');

    foreach my $file (split('\n', $output)) {
        my $file_detail = script_output("readlink $file");
        if ($file_detail !~ /(\/dev\/null|\/dev\/random)/) {

            # The file is not a softlink or doesn't link to expected device
            record_info($file, $file_detail, result => 'fail');
            $self->result('fail');
        }
        else {
            script_run('printf "File: ' . $file . ' File_detail: ' . $file_detail . ' result: Pass \n" >> ' . $test_log . '');
        }
    }
    upload_log_file($test_log);
}

1;
