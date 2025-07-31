# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Executes kselftests.
# This module introduces simplistic openqa runner for kernel selftests. The test
# module allows running tests kernel selftests from either git repository which should be
# defined in the test setting: KERNEL_GIT_TREE or from OBS/IBS repository using packaged
# and build rpm. As of May-2025 this runner is meant exclusively for cgroup tests.
# Running from git supports checking out specific git tag version of the kernel, so if required
# the tests can checkout the older version, corresponding with the kernel under tests, and run
# such tests
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

sub prepare_kselftests_from_git
{
    my ($root) = @_;

    my $git_tree = get_var('KERNEL_GIT_TREE', 'https://github.com/torvalds/linux.git');
    my $git_tag = get_var('KERNEL_GIT_TAG', '');
    zypper_call('in bc git-core ncurses-devel gcc flex bison libelf-devel libopenssl-devel kernel-devel kernel-source');
    assert_script_run("git clone --depth 1 --single-branch --branch master $git_tree linux", 240);

    assert_script_run("cd ./linux");

    if ($git_tag ne '') {
        assert_script_run("git fetch --unshallow --tags", 7200);
        assert_script_run("git checkout $git_tag");
    }

    assert_script_run("make headers");
}

sub install_kselftest_suite
{
    my ($suite) = @_;

    assert_script_run("make -j `nproc` -C tools/testing/selftests install TARGETS=$suite", 7200);
    assert_script_run("cd ./tools/testing/selftests/kselftest_install");
    assert_script_run("./run_kselftest.sh -l");
    assert_script_run("cd -");
}

sub prepare_kselftests_from_ibs
{
    my ($root) = @_;

    my $repo = get_var('KSELFTESTS_REPO', '');
    zypper_call("ar -f $repo kselftests");
    zypper_call("--gpg-auto-import-keys ref");

    my $kselftests_suite = get_var('KSELFTESTS_SUITE');
    my @kselftests_suite = split(',', $kselftests_suite);

    foreach my $i (@kselftests_suite) {
        zypper_call("install -y kselftests-$i");
    }
}

sub postprocess_kselftest_results {
    my ($self, $whitelist, $suite, $tap_file) = @_;

    my $tap_content = script_output("cat $tap_file", proceed_on_failure => 1);
    if (!$tap_content) {
        die "No TAP output found in $tap_file for $suite\n";
    }

    my $sanitized_suite_name = (split(':', $suite))[0];
    my @lines = split /\n/, $tap_content;

    my %group_failures;
    my %group_known;
    my %group_all_known;
    my $current_group;

    for my $line (@lines) {
        if ($line =~ /^\#\s*selftests:\s+cgroup:\s+(\S+)/) {
            $current_group = $1;
            next;
        }

        if ($line =~ /^\#\s*not ok\s+(\d+)\s+(.+)/ && defined $current_group) {
            my $num  = $1;
            my $name = $2;
            push @{ $group_failures{$current_group} }, $num;

            my $env = {
                product => get_var('DISTRI', '') . ':' . get_var('VERSION', ''),
                arch    => get_var('ARCH', ''),
            };

            if ($whitelist->find_whitelist_entry($env, $sanitized_suite_name, $name)) {
                $group_known{$current_group}{"$current_group/$num"} = 1;
            }
        }

        if ($line =~ /^not ok\s+\d+\s+selftests:\s+cgroup:\s+(\S+)/) {
            my $test_group = $1;
            my $fails     = $group_failures{$test_group} // [];
            my $known_map = $group_known{$test_group}    // {};

            my $all_known = (@$fails && scalar(grep { !$known_map->{$_} } @$fails) == 0);
            $group_all_known{$test_group} = $all_known;
        }
    }

    my @updated_lines;
    for my $line (@lines) {
        if ($line =~ /^\#\s*not ok\s+(\d+)\s+(.+)/) {
            my $num       = $1;
            my $test_name = $2;
            foreach my $test_group (keys %group_known) {
                if ($group_known{$test_group}{"$test_group/$num"}) {
                    $self->{result} = 'softfail';
                    record_info("Known issue", "$test_group:$test_name marked as softfail");
                    $line = "# ok $num $test_name # TODO Known issue";
                    last;
                }
            }
        }

        if ($line =~ /^not ok\s+(\d+)\s+selftests:\s+cgroup:\s+(\S+)/) {
            my ($num, $test_group) = ($1, $2);
            if ($group_all_known{$test_group}) {
                $self->{result} = 'softfail';
                record_info("Known issue", "All failed subtests in $test_group are known issues so populating TODO to the group");
                $line = "ok $num selftests: cgroup: $test_group # TODO Known issue";
            }
        }

        push @updated_lines, $line;
    }

    my $tmp_file = "/tmp/updated_tap.$$";
    script_output("cat <<'EOF' > $tmp_file\n" . join("\n", @updated_lines) . "\nEOF");
    assert_script_run("mv $tmp_file $tap_file");

    parse_extra_log(KTAP => $tap_file);
}

sub run_kselftest_case {
    my ($self, $whitelist, $suite, $timeout, $script_path) = @_;

    my $sanitized_name = $suite;
    $sanitized_name =~ s/:/_/g;

    my $cmd;
    if ($suite =~ /:/) {
        $cmd = "$script_path -o $timeout -t $suite >> $sanitized_name.tap";
    } else {
        $cmd = "$script_path -o $timeout -c $suite >> $sanitized_name.tap";
    }

    assert_script_run($cmd, 7200);
    $self->postprocess_kselftest_results($whitelist, $suite, "$sanitized_name.tap");
}

sub run {
    my ($self) = @_;
    select_serial_terminal;
    record_info('KERNEL VERSION', script_output('uname -a'));

    my $kselftest_git = get_var('KSELFTEST_FROM_GIT', 0);
    my $kselftests_suite = get_required_var('KSELFTESTS_SUITE');
    my @kselftests_suite = split(',', $kselftests_suite);
    my $timeout = get_var('KSELFTEST_TIMEOUT', 45);
    my $whitelist_file = get_var('KSELFTEST_KNOWN_ISSUES', 'https://qam.suse.de/known_issues/kselftests.yaml');
    my $whitelist = LTP::WhiteList->new($whitelist_file);

    if ($kselftest_git) {
        prepare_kselftests_from_git();

        foreach my $i (@kselftests_suite) {
            install_kselftest_suite((split(':', $i))[0]);
            assert_script_run("cd ./tools/testing/selftests/kselftest_install");
            run_kselftest_case($self, $whitelist, $i, $timeout, "./run_kselftest.sh");
            assert_script_run("cd -");
        }
    } else {
        prepare_kselftests_from_ibs("/usr/share/kselftests");

        foreach my $i (@kselftests_suite) {
            run_kselftest_case($self, $whitelist, $i, $timeout, "/usr/share/kselftests/run_kselftest.sh");
        }
    }
}

1;
