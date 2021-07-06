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

our @EXPORT = qw(
  $testdir
  $testfile_tar
  $baseline_file
  $code_repo
  $mode
  get_testsuite_name
  run_testcase
  parse_testcase_log
  compare_run_log
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
    assert_script_run("cd ${testdir}${testfile_tar}/audit-test/${testcase}/");
    assert_script_run('./run.bash', %args);

    # Upload logs
    upload_logs("$current_file");
    upload_logs("$baseline_file");
}

# Parse all test cases in *.log (run.log, etc)
# input: $file - file name
# output: @testcase_list - test case list
sub parse_testcase_log {
    my ($file) = @_;

    # Test case token, it is a number within []: e.g., [0], [1], [12]
    my $s_tok         = '\[\d+\] ';
    my @testcase_list = ();

    my @lines = split(/\n/, path("$file")->slurp);
    my $i     = 0;
    # Parse the test cases of input file
    for my $line (@lines) {
        if ($line =~ /$s_tok/) {
            push @testcase_list, "$line\n";
            $i++;
        }
    }
    record_info("T: $i", "Total \"$i\" test cases found in file \"$file\":\n @testcase_list");
    return @testcase_list;
}

# Compare baseline testing result and current testing result
# input: $testcase - test case name (the test module name in openQA code,
# if test module is 'audit_tools.pm' then $testcase = audit_tools, etc)
sub compare_run_log {
    my ($testcase) = @_;
    my $c_file     = "ulogs/${testcase}-${current_file}";
    my $b_file     = "ulogs/${testcase}-${baseline_file}";

    # Define Test case (name and result) list
    my @testcase_list_current  = ();
    my @testcase_list_baseline = ();
    my $result                 = 'ok';

    # Parse the test cases in baseline file
    record_info('Baseline', 'Parse baseline test results');
    @testcase_list_baseline = parse_testcase_log($b_file);
    record_info('Current', 'Parse current test results');
    @testcase_list_current = parse_testcase_log($c_file);
    my $str_baseline = join('', @testcase_list_baseline);
    my $str_current  = join('', @testcase_list_current);
    record_info('Compare', "Compare the testing results of current file \"$c_file\" with baseline file \"$b_file\".");
    if ($str_baseline eq $str_current) {
        $result = 'ok';
    }
    else {
        my $size = @testcase_list_baseline;
        for (my $i = 0; $i < $size; $i++) {
            if ($testcase_list_current[$i] !~ m/PASS/ && "$testcase_list_current[$i]" ne "$testcase_list_baseline[$i]") {
                record_info(
                    'Not Same',
                    "Current testing results are not same with baseline! FYI:\n\"Baseline\"=$testcase_list_baseline[$i]\" Current\"=$testcase_list_current[$i]"
                );
                $result = 'fail';
            }
        }
    }
    if ($result eq 'ok') {
        # Current run.log is the same with baseline_run.log
        record_info('Same', 'Current testing results are the same with baseline');
    }
    return $result;
}

1;
