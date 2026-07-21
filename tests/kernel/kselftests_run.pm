# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run Kselftests.
#
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';

use testapi;
use utils qw(write_sut_file);
use serial_terminal qw(serial_term_prompt select_serial_terminal);
use Kselftests::utils;
use LTP::utils qw(unmask_serial_failures);

sub pre_run_hook {
    my ($self) = @_;
    $self->{serial_failures} = unmask_serial_failures($self->{serial_failures});
    $self->SUPER::pre_run_hook;
}

sub run {
    my ($self) = @_;

    select_serial_terminal;

    my $collection = get_required_var('KSELFTEST_COLLECTION');
    $self->{collection} = $collection;

    # At this point kselftests_prepare.pm has already run: CWD has the file
    # 'kselftest-list.txt' listing all the available tests
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

    validate_kconfig($collection);

    my $timeout = get_var('KSELFTEST_TIMEOUT') // 300;
    my $stamp = 'OpenQA::kselftest_run.pm';

    export_kselftest_env();

    for my $test (@tests) {
        # Stamp the kernel ring buffer before each test
        script_run("echo '$stamp: Starting $test' > /dev/kmsg");

        my $cmd = "./run_kselftest.sh --override-timeout $timeout --per-test-log --test $test 2>&1 | tee -a \$HOME/summary.tap; echo '$stamp $test END'";

        wait_serial(serial_term_prompt(), undef, 0, no_regex => 1);
        type_string($cmd);
        wait_serial($cmd, undef, 0, no_regex => 1);
        send_key 'ret';

        # Give the harness's own --override-timeout a 10s head start so it can
        # print its TIMEOUT result and the END stamp before openQA gives up.
        my $finished = wait_serial(qr/\Q$stamp\E \Q$test\E END/, timeout => $timeout + 10, record_output => 1);
        die "Timed out waiting for kselftest '$test' which may still be running or the OS may have crashed!" unless defined $finished;
    }
}

sub post_run_hook {
    my ($self) = @_;
    $self->SUPER::post_run_hook;

    my @tests = @{$self->{tests}};
    my ($ktap, $softfails, $hardfails) = post_process(collection => $self->{collection}, tests => \@tests);

    chomp @{$ktap};
    write_sut_file('/tmp/kselftest.tap.txt', join("\n", grep { /\S/ } @{$ktap}));
    parse_extra_log(KTAP => '/tmp/kselftest.tap.txt');

    if ($softfails > 0 && $hardfails == 0) {
        $self->{result} = 'softfail';
    }
}

1;

=head1 Description

This module runs Linux Kernel Selftests (kselftests) inside openQA.
It expects C<kselftests_prepare> to have already installed the selftests
and their dependencies.

Each test in the collection is run individually so that kernel crashes or
hangs are caught per-test rather than aborting the entire run with a
single opaque timeout.

Test results are collected from KTAP output produced by the
F<run_kselftest.sh> harness and exported into the openQA result
directory.

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

=head2 KSELFTEST_TIMEOUT

Per-test timeout in seconds. If a single test does not complete within
this time, the module fails. Defaults to 300 seconds.

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
  KSELFTEST_TIMEOUT=1800
  KSELFTEST_FROM_GIT=0
