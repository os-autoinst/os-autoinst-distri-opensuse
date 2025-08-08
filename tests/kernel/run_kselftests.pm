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

use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use registration;
use utils;
use LTP::WhiteList;
use version_utils qw(is_sle);

sub install_from_git
{
    my ($collection) = @_;

    my $git_tree = get_var('KERNEL_GIT_TREE', 'https://github.com/torvalds/linux.git');
    my $git_tag = get_var('KERNEL_GIT_TAG', '');
    zypper_call('in bc git-core ncurses-devel gcc flex bison libelf-devel libopenssl-devel kernel-devel kernel-source');
    assert_script_run("git clone --depth 1 --single-branch --branch master $git_tree linux", 240);

    assert_script_run("cd ./linux");

    if ($git_tag ne '') {
        assert_script_run("git fetch --unshallow --tags", 7200);
        assert_script_run("git checkout $git_tag");
    }

    assert_script_run("make -j `nproc` -C tools/testing/selftests install TARGETS=$collection", 7200);
}

sub install_from_repo
{
    my $repo = get_var('KSELFTEST_REPO', '');
    zypper_call("ar -f $repo kselftests");
    zypper_call("--gpg-auto-import-keys ref");
    zypper_call("install -y kselftests");
}

sub post_process {
    my ($self, $collection, @tests) = @_;

    my $default_whitelist_file = 'https://raw.githubusercontent.com/openSUSE/kernel-qe/refs/heads/main/kselftests_known_issues.yaml';
    if (is_sle) {
        $default_whitelist_file = 'https://qam.suse.de/known_issues/kselftests.yaml';
    }
    my $whitelist_file = get_var('KSELFTEST_KNOWN_ISSUES', $default_whitelist_file);
    my $whitelist = LTP::WhiteList->new($whitelist_file);
    my $env = {
        product => get_var('DISTRI', '') . ':' . get_var('VERSION', ''),
        arch => get_var('ARCH', ''),
    };

    my @full_ktap;
    my @summary = split(/\n/, script_output("cat summary.tap"));
    my $summary_ln_idx = 0;
    my $test_index = 0;

    for my $test (@tests) {
        $test_index++;
        my $test_name = $test =~ s/^\w+://r;    # Remove the $collection from it

        # Check test result in the summary
        my $summary_ln;
        while ($summary_ln_idx < @summary) {
            $summary_ln = $summary[$summary_ln_idx];
            $summary_ln_idx++;
            if ($summary_ln =~ /^(not )?ok \d+ selftests: \S+: \S+/) {
                my $test_failed = $summary_ln =~ /^not ok/ ? 1 : 0;
                if ($test_failed && $whitelist->find_whitelist_entry($env, $collection, $test_name)) {
                    $self->{result} = 'softfail';
                    record_info("Known Issue", "$test marked as softfail");
                    $summary_ln = "ok $test_index selftests: $collection: $test_name # TODO Known Issue";
                }
                # Break and keep the index so that we only read each line in the summary once
                last;
            } else {
                # Push all lines that are not test results to the full log
                push(@full_ktap, $summary_ln);
            }
        }

        # Check each subtest result in the individual test log
        my @log = split(/\n/, script_output("cat /tmp/$test_name"));    # When using `--per-test-log`, that's where they are found
        my $hardfails = 0;
        my $fails = 0;
        for my $test_ln (@log) {
            if ($test_ln =~ /^# not ok (\d+) (\S+)/) {
                my $subtest_idx = $1;
                my $subtest_name = $2;
                if ($whitelist->find_whitelist_entry($env, $collection, $subtest_name)) {
                    $self->{result} = 'softfail';
                    record_info("Known Issue", "$test:$subtest_name marked as softfail");
                    $test_ln = "# ok $subtest_idx $subtest_name # TODO Known Issue";
                } else {
                    $hardfails++;
                }
                $fails++;
            }
            push(@full_ktap, $test_ln);
        }

        if ($fails > 0 && $hardfails == 0) {
            record_info("Known Issue", "All failed subtests in $test are known issues; propagating TODO directive to the top-level");
            $summary_ln = "ok $test_index selftests: $collection: $test_name # TODO Known Issue";
        }

        push(@full_ktap, $summary_ln);
    }

    script_output("cat <<'EOF' > kselftest.tap.txt\n" . join("\n", @full_ktap) . "\nEOF");
    parse_extra_log(KTAP => 'kselftest.tap.txt');    # Append .txt so that it can be easily previewed within openQA
}

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

    # Filter which tests will run using KSELFTEST_TESTS
    my @tests = split /,/, get_var('KSELFTEST_TESTS', '');
    if (!@tests) {
        @tests = @all_tests;
    }

    # Filter which tests will *NOT* run using KSELFTEST_SKIP
    my @skip = split /,/, get_var('KSELFTEST_SKIP', '');
    if (@skip) {
        my %skip = map { $_ => 1 } @skip;
        # Remove tests that are in @skip
        @tests = grep { !$skip{$_} } @tests;
    }

    # Run specific tests if the arrays have different lengths
    my $tests = '';
    if (@tests == @all_tests) {
        $tests = "--collection $collection";
    } else {
        $tests .= "--test $_ " for @tests;
    }

    my $timeout = get_var('KSELFTEST_TIMEOUT', 45);    # Individual timeout for each test in the collection
    assert_script_run("./run_kselftest.sh --per-test-log --override-timeout $timeout $tests > summary.tap", 7200);
    $self->post_process($collection, @tests);
}

1;
