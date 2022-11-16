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
    autotest::loadtest("$test.pm", %args);
}

# Load mr_test according to 'Settings': 'MR_TEST'.
#   - "$test_list": test case list got from 'MR_TEST'.
sub load_mr_tests {
    my ($test_list, $args) = @_;
    my $i = 1;
    my $note_solution = '';

    # The main script which dynamically generates test modules (*.pm) according to 'MR_TEST' value
    my $script = 'tests/sles4sap/saptune/mr_test_run';
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

    # Load 'ssh_interactive_end.pm' here instead of adding to 'schedule/sles4sap/sles4sap_gnome_saptune.yaml'
    # otherwise 'ssh_interactive_end.pm' will be started to run before 'load_mr_tests' finished.
    # Paste the messages which are cut out from openQA log file FYI for a better understanding:
    #   [debug] ||| starting mr_test tests/sles4sap/saptune/mr_test.pm
    #   [debug] ||| finished mr_test sles4sap/saptune
    #   [debug] scheduling 1_saptune_notes .../mr_test_run.pm
    #   [debug] ||| starting ssh_interactive_end tests/publiccloud/ssh_interactive_end.pm
    #   [debug] ||| finished ssh_interactive_end publiccloud
    #   [debug] ||| starting 1_saptune_notes .../mr_test_run.pm
    #   [debug] ||| finished 1_saptune_notes lib
    loadtest_mr_test('tests/publiccloud/ssh_interactive_end', run_args => $args) if get_var('PUBLIC_CLOUD_SLES4SAP');
}

1;
