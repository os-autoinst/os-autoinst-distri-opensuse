# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Base module for audit-test test cases
# Maintainer: QE Security <none@suse.de>

package audit_test;

use base Exporter;

use strict;
use warnings;
use testapi;
use utils;
use Utils::Architectures;
use Mojo::File 'path';
use Mojo::Util 'trim';

our @EXPORT = qw(
  $tmp_dir
  $test_dir
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
  rerun_fail_cases
  parse_kvm_svirt_apparmor_results
);

our $tmp_dir = '/tmp/';
our $test_dir = get_var('IPSEC_TEST') ? '/usr/local/ipsec' : '/usr/local/eal4_testing';
our $default_code_base = get_var('IPSEC_TEST') ? 'https://gitlab.suse.de/qe-security/ipsec/-/archive/main/ipsec-main.tar' : 'https://gitlab.suse.de/security/audit-test-sle15/-/archive/master/audit-test-sle15-master.tar';
our $code_repo = get_var('CODE_BASE', $default_code_base);
my @lines = split(/[\/\.]+/, $code_repo);
our $testfile_tar = $lines[-2];
our $mode = get_var('MODE', 64);

# $current_file: current output file name; $baseline_file: baseline file name
our $current_file = 'run.log';
our $baseline_file = 'baseline_run.log';

# Run the specific test case
# input: $testcase - test case name (the actual test case name is in corresponding 'audit-test' test suite,
# e.g. "kvm", 'audit-tools', 'syscalls')
sub run_testcase {
    my ($testcase, %args) = @_;

    # Configure the test environment for test
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
    upload_audit_test_logs($testcase);
}

sub upload_audit_test_logs {
    my ($testcase) = @_;
    upload_logs("$current_file");

    # Base line file is ARCH specific in some cases,
    # so we need to upload the correct file for each platform.
    $baseline_file = 'baseline_run.log.' . get_var('ARCH');
    if (script_run("test -e $baseline_file") != 0) {
        $baseline_file = "baseline_run.log";
    }
    upload_logs("$baseline_file", (log_name => "$testcase-baseline_run.log"));
}

sub prepare_for_test {
    my (%args) = @_;

    # Run test case
    assert_script_run("cd ${test_dir}/audit-test/");
    assert_script_run('make') if ($args{make});
    assert_script_run('make netconfig') if ($args{make_netconfig});

    # Export MODE
    assert_script_run("export MODE=$audit_test::mode");

    # Which test cases are loaded depends on the ARCH
    assert_script_run("export ARCH=s390x") if (is_s390x);
    assert_script_run("export ARCH=aarch") if (is_aarch64);
}

sub parse_lines {
    my ($lines) = @_;
    my @results;
    foreach my $line (@$lines) {
        if ($line =~ /\[(\d+)\]\s+(.*)\s+(PASS|FAIL|ERROR)/) {
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
    my $output = script_output('cat ./rollup.log');
    my @lines = split(/\n/, $output);
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
        my $c_id = $current_result->{id};
        my $c_result = $current_result->{result};
        my $name = $current_result->{name};
        unless ($baseline_results{$c_id}) {
            my $msg = "poo#93441\nNo baseline found(defined).\n[$c_id] $name $c_result";
            $flag = _parse_results_with_diff_baseline($name, $c_result, $msg, $flag);
            next;
        }
        my $b_name = $baseline_results{$c_id}->{name};
        my $b_result = $baseline_results{$c_id}->{result};
        if ($c_result ne $b_result) {
            my $info = "Test result is NOT same as baseline \nCurrent:  [$c_id] $name $c_result\nBaseline: [$c_id] $b_name $b_result";
            $flag = _parse_results_with_diff_baseline($name, $c_result, $info, $flag);
            next;
        }
        record_info($name, "Test result is the same as baseline\n[$c_id] $name $c_result", result => 'ok');
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
    my $softfail_tests = {};
    if ($result eq 'PASS') {
        record_info('Softfail', $msg, result => 'softfail');
        $flag = 'softfail' if ($flag ne 'fail');
    }
    else {
        my $arch = get_var('ARCH');
        if ($softfail_tests->{$arch}) {
            if (my $reason = $softfail_tests->{$arch}->{$name}) {
                record_info('Softfail', $msg . "\n" . $reason, result => 'softfail');
                return 'softfail';
            }
        }
        record_info($name, $msg, result => 'fail');
        $flag = 'fail';
    }
    return $flag;
}

# Sometimes the test cases will fail due to performance issue or something else reason.
# And rerun this case may work, so we will rerun the cases which usually fail randomly.
#
sub rerun_fail_cases {
    my $fail_case = shift;
    my $output = script_output('grep -E "FAIL|ERROR" rollup.log', proceed_on_failure => 1);
    return if ($output eq '');

    my @lines = split(/\n/, $output);
    my @current_results = parse_lines(\@lines);

    unless ($fail_case) {
        script_run("./run.bash $_->{id}", timeout => 180) for (@current_results);
        return;
    }

    my %rerun_cases = map { ($_->{id} => $_->{timeout}) } @$fail_case;
    foreach my $fail_case (@current_results) {
        my $case_id = $fail_case->{id};
        if (exists $rerun_cases{$case_id}) {
            script_run("./run.bash $case_id", timeout => $rerun_cases{$case_id} // 180);
        }
    }
}

# The test code kvm_svirt_arrarmor is used by two tests.
# We need to parse log file to check the results.
# For kvm svirt apparmor, all test cases should pass.
# For AppArmor negative test, some cases should fail.
sub parse_kvm_svirt_apparmor_results {
    my $test_name = shift;
    my $log_file = '/tmp/vm-sep/vm-sep-crack.log';
    assert_script_run("[[ -e $log_file ]]");
    my $test_results = {};
    my @fail_cases;
    my $result = 'ok';
    my $output = script_output("cat $log_file");
    my @lines = split(/\n/, $output);

    foreach (@lines) {
        if ($_ =~ /Number of tests (executed|failed|passed):\s+(\d+)/) {
            $test_results->{$1} = $2;
        }
        if ($_ =~ /(.*):(.*?)FAILED$/) {
            push @fail_cases, $1;
        }
    }
    if ($test_name eq 'kvm_svirt_apparmor') {
        $result = 'fail' if ($test_results->{passed} ne $test_results->{executed});
    }

    if ($test_name eq 'apparmor_negative_test') {
        my $total_num = $test_results->{passed} + scalar(@fail_cases);
        $result = 'fail' if ($test_results->{executed} ne $total_num);
        my $expected_fail_cases = {
            'Test read access to file /tmp/vm-sep/vm-sep-slave.disk prevented' => 1,
            'Test write access to file /tmp/vm-sep/vm-sep-slave.disk prevented' => 1,
            'Children of confined process still confined' => 1
        };
        foreach my $fail_case (@fail_cases) {
            unless ($expected_fail_cases->{$fail_case}) {
                $result = 'fail';
                record_info($fail_case, "Case $fail_case should fail as expect.", result => 'fail');
            }
        }
    }

    upload_logs($log_file);
    return $result;
}

1;
