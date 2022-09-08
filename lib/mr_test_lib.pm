# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Base module for saptune "mr_test" test cases.
#          It dynamically generates test modules (*.pm) according to 'MR_TEST'.
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

sub loadtest_mr_test {
    my ($test, %args) = @_;
    autotest::loadtest("lib/$test.pm", %args);
}

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
