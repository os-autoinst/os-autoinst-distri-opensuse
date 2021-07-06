# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Base module for audit-test test cases
# Maintainer: llzhao <llzhao@suse.com>

package audit_test;

use base Exporter;

use strict;
use warnings;
use testapi;
use utils;
use Mojo::File 'path';
use Mojo::Util 'trim';

our @EXPORT = qw(
  $testdir
  $testfile_tar
  $baseline_file
  $code_repo
  $mode
  get_testsuite_name
  run_testcase
  compare_run_log
  parse_lines
);

our $testdir      = '/tmp/';
our $code_repo    = get_var('CODE_BASE', 'https://gitlab.suse.de/security/audit-test-sle15/-/archive/master/audit-test-sle15-master.tar');
our $testfile_tar = 'audit-test-sle15-master';
our $mode         = get_var('MODE', 64);

# $current_file: current output file name; $baseline_file: baseline file name
our $current_file  = 'run.log';
our $baseline_file = 'baseline_run.log';

# Run the specific test case
# input: $testcase - test case name (the actual test case name in 'audit-test' test suite, etc)
sub run_testcase {
    my ($testcase, %args) = @_;

    # Run test case
    assert_script_run("cd ${testdir}${testfile_tar}/audit-test/");
    assert_script_run('make') if ($args{make});
    assert_script_run("cd ${testcase}/");

    # Export MODE
    assert_script_run("export MODE=$audit_test::mode");

    assert_script_run('./run.bash', timeout => $args{timeout});

    # Upload logs
    upload_logs("$current_file");
    upload_logs("$baseline_file");
}

sub parse_lines {
    my ($lines) = @_;
    my @results;
    foreach my $line (@$lines) {
        if ($line =~ /(\[\d+\])\s+(.*)\s+(PASS|FAIL|ERROR)/) {
            my $name = trim $2;
            push @results, {id => $1, name => $name, result => $3};
        }
    }
    return @results;
}

# Compare baseline testing result and current testing result
# input: $testcase - test case name (the test module name in openQA code,
# if test module is 'audit_tools.pm' then $testcase = audit_tools, etc)
sub compare_run_log {
    my ($testcase) = @_;

    # Read the current test result from rollup.log
    my $output          = script_output('cat ./rollup.log');
    my @lines           = split(/\n/, $output);
    my @current_results = parse_lines(\@lines);

    my %baseline_results;
    my $baseline_file = "ulogs/$testcase-baseline_run.log";
    if (!-e $baseline_file) {
        diag "The file $baseline_file does not exist";
    }
    else {
        my @lines = split(/\n/, path("$baseline_file")->slurp);
        %baseline_results = map { $_->{name} => {id => $_->{id}, result => $_->{result}} } parse_lines(\@lines);
    }

    my $flag = 'ok';
    foreach my $current_result (@current_results) {
        my $c_id     = $current_result->{id};
        my $c_result = $current_result->{result};
        my $key      = $current_result->{name};
        unless ($baseline_results{$key}) {
            my $msg = "poo#93441\nNo baseline found(defined).\n$c_id $key $c_result";
            $flag = _parse_results_with_diff_baseline($key, $c_result, $msg, $flag);
            next;
        }
        my $b_id     = $baseline_results{$key}->{id};
        my $b_result = $baseline_results{$key}->{result};
        if ($c_result ne $b_result) {
            my $info = "poo#93441\nTest result is NOT same as baseline \nCurrent:  $c_id $key $c_result\nBaseline: $b_id $key $b_result";
            $flag = _parse_results_with_diff_baseline($key, $c_result, $info, $flag);
            next;
        }
        record_info($key, "Test result is the same as baseline\n$c_id $key $c_result", result => 'ok');
    }
    return $flag;
}

# When the current result is different with baseline, according to current result
# the test result shown on openQA is different.
# Rules for test result
# No baseline:
# Current result    test result shown on openQA
# PASS              softfail
# ERROR             fail
# FAIL              fail
#
# different with baseline:
# Current result   Baseline     test result shown on openQA
# PASS             FAIL/ERROR   softfail
# FAIL             PASS/ERROR   fail
# ERROR            PASS/FAIL    fail
#
sub _parse_results_with_diff_baseline {
    my ($name, $result, $msg, $flag) = @_;
    if ($result eq 'PASS') {
        record_soft_failure($msg);
        $flag = 'softfail' if ($flag ne 'fail');
    }
    else {
        record_info($name, $msg, result => 'fail');
        $flag = 'fail';
    }
    return $flag;
}

1;
