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
    if (get_var('KSELFTEST_FROM_GIT', 0)) {
        install_from_git($collection);
        assert_script_run("cd ./tools/testing/selftests/kselftest_install");
    } else {
        install_from_repo();
        assert_script_run("cd /usr/share/kselftests");
    }

    # At this point, CWD has the file 'kselftest-list.txt' listing all the available tests
    my @all_tests = split(/\n/, script_output("./run_kselftest.sh --list | grep '^$collection'"));
    record_info("Available Tests", join("\n", @all_tests));

    # Filter which tests will run using KSELFTEST_TESTS
    my @tests = @{get_var_array('KSELFTEST_TESTS')};
    @tests = @all_tests unless @tests;
    chomp @tests;

    # Filter which tests will *NOT* run using KSELFTEST_SKIP
    my @skip = map { s/^\s+|\s+$//gr } @{get_var_array('KSELFTEST_SKIP')};
    if (@skip) {
        record_info("Skipping Tests", join("\n", @skip));
        my %skip = map { $_ => 1 } @skip;
        # Remove tests that are in @skip
        @tests = grep { !$skip{$_} } @tests;
    }
    $self->{tests} = [@tests];

    # Run specific tests if the arrays have different lengths
    my $tests = '';
    if (@tests == @all_tests) {
        record_info("Running Collection", $collection);
        $tests = "--collection $collection";
    } else {
        record_info("Running Tests", join("\n", @tests));
        $tests = join(' ', map { "--test $_" } @tests);
    }

    validate_kconfig($collection);

    my $stamp = 'OpenQA::run_kselftest.pm';
    my $timeout = get_var('KSELFTEST_TIMEOUT') // 300;
    my $test_timeout = get_var('KSELFTEST_TEST_TIMEOUT') ? "--override-timeout " . get_var('KSELFTEST_TEST_TIMEOUT') : '';
    my $single = @tests > 1 ? '--per-test-log' : '';
    my $runner = get_var('KSELFTEST_RUNNER') // "./run_kselftest.sh $test_timeout $single $tests";
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

    write_sut_file('/tmp/kselftest.tap.txt', join("\n", @{$ktap}));
    parse_extra_log(KTAP => '/tmp/kselftest.tap.txt');

    if ($softfails > 0 && $hardfails == 0) {
        $self->{result} = 'softfail';
    }
}

1;
