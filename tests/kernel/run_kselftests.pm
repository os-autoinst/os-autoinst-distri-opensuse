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
use serial_terminal 'select_serial_terminal';
use Kselftests::utils;

sub run {
    my ($self) = @_;

    select_serial_terminal;
    record_info('KERNEL VERSION', script_output('uname -a'));

    my $collection = get_required_var('KSELFTEST_COLLECTION');
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

    # Filter which tests will *NOT* run using KSELFTEST_SKIP
    my @skip = map { s/^\s+|\s+$//gr } @{get_var_array('KSELFTEST_SKIP')};
    if (@skip) {
        record_info("Skipping Tests", join("\n", @skip));
        my %skip = map { $_ => 1 } @skip;
        # Remove tests that are in @skip
        @tests = grep { !$skip{$_} } @tests;
    }

    # Run specific tests if the arrays have different lengths
    my $tests = '';
    if (@tests == @all_tests) {
        record_info("Running Collection", $collection);
        $tests = "--collection $collection";
    } else {
        record_info("Running Tests", join("\n", @tests));
        $tests .= "--test $_ " for @tests;
    }

    my $timeout = '';
    if ($timeout = get_var('KSELFTEST_TIMEOUT')) {
        $timeout = "--override-timeout $timeout";    # Individual timeout for each test in the collection
    }

    validate_kconfig($collection);

    my ($ktap, $softfails, $hardfails);
    my $runner = '';
    if ($runner = get_var('KSELFTEST_RUNNER')) {
        script_run("$runner > summary.tap 2>&1", 7200);
        ($ktap, $softfails, $hardfails) = post_process_single(collection => $collection, test => $tests[0]);
    } else {
        assert_script_run("./run_kselftest.sh --per-test-log $timeout $tests | tee summary.tap", 7200);
        ($ktap, $softfails, $hardfails) = post_process(collection => $collection, tests => \@tests);
    }

    write_sut_file('/tmp/kselftest.tap.txt', join("\n", @{$ktap}));
    parse_extra_log(KTAP => '/tmp/kselftest.tap.txt');

    if ($softfails > 0 && $hardfails == 0) {
        $self->{result} = 'softfail';
    }
}

1;
