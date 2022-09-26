# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Base module for saptune "mr_test" test cases.
#          It dynamically generates test modules according to 'MR_TEST'
#          and runs these modules by script 'mr_test_run.pm'.
#          E.g., MR_TEST="1410736,S4HANA-APP+DB,solutions"
# Maintainer: llzhao <llzhao@suse.com>
# Tags: jsc#TEAM-6726

package mr_test_lib;

use strict;
use warnings;
use testapi;
use utils;
use autotest;

use base 'consoletest';
use LTP::TestInfo 'testinfo';
use mr_test_run qw(get_notes get_solutions);

our @EXPORT = qw(
  load_mr_tests
);

# Load test case automatically.
#   - "$test": the test scritpt/module to be run;
#   - "%args": the arguments of "$test".
sub loadtest_mr_test {
    my ($test, %args) = @_;
    autotest::loadtest("lib/$test.pm", %args);
}

# Load mr_test according to 'Settings': 'MR_TEST'.
#   - "$test_list": test case list got from 'MR_TEST'.
sub load_mr_tests {
    my ($test_list) = @_;
    my $i = 1;
    my $note_solution = '';

    # The main script which dynamically generates test modules (*.pm) according to 'MR_TEST' value
    my $script = 'mr_test_run';
    my $tinfo = testinfo({}, test => $script);
    for my $test (split(/,/, $test_list)) {
        $note_solution = '';
        if (grep { /^${test}$/ } mr_test_run::get_solutions()) {
            $note_solution = 'solution_';
        }
        elsif (grep { /^${test}$/ } mr_test_run::get_notes()) {
            $note_solution = 'note_';
        }
        $tinfo = testinfo({}, test => $test);
        loadtest_mr_test("$script", name => $i . '_saptune_' . $note_solution . $test, run_args => $tinfo);
        $i++;
    }
}

1;
