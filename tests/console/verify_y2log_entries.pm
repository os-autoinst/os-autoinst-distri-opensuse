# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Check that YaST logs contain expected entries. This module is
#          test_data driven, following structure should be used:
# test_data:
#   y2log:
#     - entry: 'Some additional space'
#       fail_message: 'here where no warnings for partition shrinking in y2log'
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use parent 'y2_module_consoletest';
use testapi;
use scheduler;

sub run {
    my $test_data = get_test_suite_data();

    select_console 'root-console';
    # Accumulate errors for all checks
    my $errors = '';

    foreach my $entry (@{$test_data->{y2log}}) {
        if (script_run("zgrep '$entry->{entry_text}' /var/log/YaST2/y2log*") != 0) {
            $errors .= "Entry '$entry->{entry_text}' is not found in y2logs:";
            $errors .= $entry->{fail_message} ? "\n$entry->{fail_message}\n" : "\n";
        }
    }

    die "y2log entries validation failed:\n$errors" if $errors;
}

1;
