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
  prepare_for_test
  upload_audit_test_logs
);

our $testdir   = '/tmp/';
our $code_repo = get_var('CODE_BASE', 'https://gitlab.suse.de/security/audit-test-sle15/-/archive/master/audit-test-sle15-master.tar');
my @lines = split(/[\/\.]+/, $code_repo);
our $testfile_tar = $lines[-2];
our $mode         = get_var('MODE', 64);

# $current_file: current output file name; $baseline_file: baseline file name
our $current_file  = 'run.log';
our $baseline_file = 'baseline_run.log';

# Run the specific test case
# input: $testcase - test case name (the actual test case name is in corresponding 'audit-test' test suite,
# e.g. "kvm", 'audit-tools', 'syscalls')
sub run_testcase {
    my ($testcase, %args) = @_;

    # Configure the test enviornment for test
    prepare_for_test(%args) unless ($args{skip_prepare});

    assert_script_run("cd ${testcase}/");
    # Test case 'audit-remote-libvirt' does not generate any logs
    if ($testcase eq 'audit-remote-libvirt') {
        # Note: the outputs of run.bash can not be saved to "./$file", so save to "../$file"
        script_run("./run.bash 1>../$current_file 2>&1", timeout => $args{timeout});
        assert_script_run("mv ../$current_file $current_file");
        assert_script_run("cat $current_file");
        assert_script_run("cp $current_file ./rollup.log");
    }
    else {
        assert_script_run('./run.bash', timeout => $args{timeout});
    }
    upload_audit_test_logs();
}

sub upload_audit_test_logs {
    upload_logs("$current_file");
    upload_logs("$baseline_file");
}

sub prepare_for_test {
    my (%args) = @_;

    # Run test case
    assert_script_run("cd ${testdir}${testfile_tar}/audit-test/");
    assert_script_run('make')           if ($args{make});
    assert_script_run('make netconfig') if ($args{make_netconfig});

    # Export MODE
    assert_script_run("export MODE=$audit_test::mode");
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
        %baseline_results = map { $_->{id} => {name => $_->{name}, result => $_->{result}} } parse_lines(\@lines);
    }

    my $flag = 'ok';
    foreach my $current_result (@current_results) {
        my $c_id     = $current_result->{id};
        my $c_result = $current_result->{result};
        my $name     = $current_result->{name};
        unless ($baseline_results{$c_id}) {
            my $msg = "poo#93441\nNo baseline found(defined).\n$c_id $name $c_result";
            $flag = _parse_results_with_diff_baseline($name, $c_result, $msg, $flag);
            next;
        }
        my $b_name   = $baseline_results{$c_id}->{name};
        my $b_result = $baseline_results{$c_id}->{result};
        if ($c_result ne $b_result) {
            my $info = "poo#93441\nTest result is NOT same as baseline \nCurrent:  $c_id $name $c_result\nBaseline: $c_id $b_name $b_result";
            $flag = _parse_results_with_diff_baseline($name, $c_result, $info, $flag);
            next;
        }
        record_info($name, "Test result is the same as baseline\n$c_id $name $c_result", result => 'ok');
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
