# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Execute Kselftests.
#
# This module introduces a simplistic openQA runner for kernel selftests. The test
# module allows running tests kernel selftests from either git repository which should be
# defined in the test setting: KERNEL_GIT_TREE or from OBS/IBS repository using packaged
# and build rpm.
# Running from git supports checking out specific git tag version of the kernel, so if required
# the tests can checkout the older version, corresponding with the kernel under tests, and run
# such tests.
#
# Maintainer: Kernel QE <kernel-qa@suse.de>

use base 'opensusebasetest';

use testapi;
use utils qw(write_sut_file);
use serial_terminal qw(serial_term_prompt select_serial_terminal);
use Kselftests::utils;

sub run {
    my ($self) = @_;

    select_serial_terminal;
    record_info('KERNEL VERSION', script_output('uname -a'));

    my $collection = get_required_var('KSELFTEST_COLLECTION');
    $self->{collection} = $collection;
    install_kselftests($collection);

    # At this point, CWD has the file 'kselftest-list.txt' listing all the available tests
    my @available = split(/\n/, script_output("./run_kselftest.sh --list | grep '^$collection'"));
    record_info("Available Tests", join("\n", @available));

    # Filter which tests will run using KSELFTEST_TESTS
    my @selected = @available;
    if (get_var('KSELFTEST_TESTS')) {
        @selected = @{get_var_array('KSELFTEST_TESTS')};
        chomp @selected;
    }
    my @tests = @selected;

    # Filter which tests will *NOT* run using KSELFTEST_SKIP
    my @skip = map { s/^\s+|\s+$//gr } @{get_var_array('KSELFTEST_SKIP')};
    if (@skip) {
        record_info("Skipping Tests", join("\n", @skip));
        my %skip = map { $_ => 1 } @skip;
        # Remove tests that are in @skip
        @tests = grep { !$skip{$_} } @tests;
    }

    # Save the tests that are going to be run to the object so they can be later post-processed.
    $self->{tests} = [@tests];
    die 'No tests to run.' unless @tests > 0;

    my $test_opt = @tests > 1 ? '--per-test-log' : '';
    if (@selected == @available && !@skip) {
        # No tests were selected nor skipped, run full collection
        $test_opt .= " --collection $collection";
    } elsif (@selected == @available && @skip) {
        # No tests were selected but some must be skipped
        if (script_output('./run_kselftest.sh -h') =~ m/--skip/) {
            # Use `--skip` if runner allows, this is important for collections that have a high number of tests
            $test_opt .= " --collection $collection " . join(' ', map { "--skip $_" } @skip);
        } else {
            $test_opt .= ' ' . join(' ', map { "--test $_" } @tests);
        }
    } else {
        # Some tests were selected and/or skipped, simply use `--test`
        $test_opt .= ' ' . join(' ', map { "--test $_" } @tests);
    }

    validate_kconfig($collection);

    my $stamp = 'OpenQA::run_kselftest.pm';
    my $timeout = get_var('KSELFTEST_TIMEOUT') // 300;
    my $test_timeout = get_var('KSELFTEST_TEST_TIMEOUT') ? "--override-timeout " . get_var('KSELFTEST_TEST_TIMEOUT') : '';
    my $runner = get_var('KSELFTEST_RUNNER') // "./run_kselftest.sh $test_timeout $test_opt";
    $runner .= " | tee -a \$HOME/summary.tap; echo $stamp END";
    my $env = get_var('KSELFTEST_ENV') // '';
    $runner = $env . " $runner";

    script_run("echo '$stamp BEGIN' > /dev/kmsg");
    wait_serial(serial_term_prompt(), undef, 0, no_regex => 1);
    type_string($runner);
    wait_serial($runner, undef, 0, no_regex => 1);
    send_key 'ret';

    my $finished = wait_serial(qr/$stamp END/, timeout => $timeout, expect_not_found => 0, record_output => 1);
    if (not defined $finished) {
        die "Timed out waiting for Kselftests runner which may still be running or the OS may have crashed!";
    }
}

sub post_run_hook {
    my ($self) = @_;
    $self->SUPER::post_run_hook;

    my ($ktap, $softfails, $hardfails);
    my @tests = @{$self->{tests}};
    if (@tests > 1) {
        ($ktap, $softfails, $hardfails) = post_process(collection => $self->{collection}, tests => \@tests);
    } else {
        ($ktap, $softfails, $hardfails) = post_process_single(collection => $self->{collection}, test => $tests[0]);
    }

    chomp @{$ktap};
    write_sut_file('/tmp/kselftest.tap.txt', join("\n", grep { /\S/ } @{$ktap}));
    parse_extra_log(KTAP => '/tmp/kselftest.tap.txt');

    if ($softfails > 0 && $hardfails == 0) {
        $self->{result} = 'softfail';
    }
}

1;

=head1 Description

This module executes Linux Kernel Selftests (kselftests) inside openQA.
It supports running tests either from the in-tree git repository or from
the packaged kselftest RPMs provided by OBS/IBS.

The module groups tests by a collection, as listed in
F<kselftest-list.txt>, and allows selecting individual tests, skipping
tests, and injecting custom environment variables into the test harness.

Test results are collected from KTAP output produced by the
F<run_kselftest.sh> harness and exported into the openQA result
directory. When multiple tests are executed, per-test logs are enabled
automatically.

A serial console stamp is written before and after the test run to
detect hangs or kernel crashes. A global timeout is applied to the
overall test run, while an optional per-test timeout can be used to
override the default 45-second limit built into the kselftest harness.

=head1 Configuration

The kselftest module is configured through openQA test variables:

=head2 KSELFTEST_COLLECTION (required)

Specifies the name of the kselftest collection to run, as reported by:

  run_kselftest.sh --list

=head2 KSELFTEST_TESTS

Optional list of individual tests to run from within the selected
collection. When not provided, the entire collection is executed.

=head2 KSELFTEST_SKIP

Optional list of tests that should be skipped. This is applied after
KSELFTEST_TESTS, so it can exclude tests even when running a full
collection.

=head2 KSELFTEST_FROM_GIT

If set, kselftests are installed from a kernel git tree instead of using
packaged RPMs. Allows to point to C<KERNEL_GIT_TREE>. Defaults to the
upstream tree: C<torvalds/linux.git>.

=head2 KSELFTEST_RUNNER

Overrides the default runner command. Useful for debugging or running
custom wrappers. Example:

  KSELFTEST_RUNNER="cd bpf; strace ./test_progs -t dummy_st_ops"

=head2 KSELFTEST_TIMEOUT

Applies a global timeout (in seconds) to the entire kselftest run. If
the tests do not complete within this time, the module fails.

=head2 KSELFTEST_TEST_TIMEOUT

Optional per-test timeout passed to F<run_kselftest.sh> via the
C<--override-timeout> argument. This overrides the default kselftest
per-test timeout (typically 45 seconds). Useful for long-running tests.

=head2 KSELFTEST_ENV

Optional string containing a list of environment variables to inject
into the kselftest runner. Useful to pass down arguments to specific
tests via run_kselftest.sh.

More details are in the upstream
F<tools/testing/selftests/kselftest/runner.sh>.

Example:

  KSELFTEST_ENV="KSELFTEST_TEST_PROGS_CPUV4_ARGS='-v -t verifier'"

=head1 Example openQA Settings

  KSELFTEST_COLLECTION=cgroup
  KSELFTEST_TESTS=test_cpucg_stats,test_cpucg_max
  KSELFTEST_TEST_TIMEOUT=120
  KSELFTEST_TIMEOUT=1800
  KSELFTEST_FROM_GIT=0
