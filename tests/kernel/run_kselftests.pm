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

sub install_from_ibs
{
    my ($collection) = @_;

    my $repo = get_var('KSELFTESTS_REPO', '');
    zypper_call("ar -f $repo kselftests");
    zypper_call("--gpg-auto-import-keys ref");

    zypper_call("install -y kselftests-$collection");
}

sub postprocess_results {
    my ($self, $collection, $tap_file) = @_;

    my $whitelist_file = get_var('KSELFTEST_KNOWN_ISSUES', 'https://qam.suse.de/known_issues/kselftests.yaml');
    my $whitelist = LTP::WhiteList->new($whitelist_file);

    my $tap_content = script_output("cat $tap_file", proceed_on_failure => 1);
    if (!$tap_content) {
        die "No TAP output found in $tap_file for $collection\n";
    }

    my @lines = split /\n/, $tap_content;

    my %group_failures;
    my %group_known;
    my %group_all_known;
    my $current_group;

    for my $line (@lines) {
        if ($line =~ /^\#\s*selftests:\s+(\S+):\s+(\S+)/) {
            $current_group = "$1:$2";
            next;
        }

        if ($line =~ /^\#\s*not ok\s+(\d+)\s+(.+)/ && defined $current_group) {
            my $num = $1;
            my $name = $2;
            push @{$group_failures{$current_group}}, $num;

            my $env = {
                product => get_var('DISTRI', '') . ':' . get_var('VERSION', ''),
                arch => get_var('ARCH', ''),
            };

            if ($whitelist->find_whitelist_entry($env, $collection, $name)) {
                $group_known{$current_group}{$num} = 1;
            }
        }

        if ($line =~ /^not ok\s+\d+\s+selftests:\s+(\S+):\s+(\S+)/) {
            my $grp = "$1:$2";
            my $fails = $group_failures{$grp} // [];
            my $known_map = $group_known{$grp} // {};

            my $all_known = (@$fails && scalar(grep { !$known_map->{$_} } @$fails) == 0);
            $group_all_known{$grp} = $all_known;
        }
    }

    my @updated_lines;
    my $current_group_for_update;
    for my $line (@lines) {
        if ($line =~ /^\#\s*selftests:\s+(\S+):\s+(\S+)/) {
            $current_group_for_update = "$1:$2";
            push @updated_lines, $line;
            next;
        }

        if ($line =~ /^\#\s*not ok\s+(\d+)\s+(.+)/ && defined $current_group_for_update) {
            my $num = $1;
            my $test_name = $2;
            if ($group_known{$current_group_for_update}{$num}) {
                $self->{result} = 'softfail';
                record_info("Known issue", "$current_group_for_update:$test_name marked as softfail");
                $line = "# ok $num $test_name # TODO Known issue";
            }
        }

        if ($line =~ /^not ok\s+(\d+)\s+selftests:\s+(\S+):\s+(\S+)/) {
            my ($num, $suite_group, $sub_group) = ($1, $2, $3);
            my $grp = "$suite_group:$sub_group";
            if ($group_all_known{$grp}) {
                $self->{result} = 'softfail';
                record_info("Known issue", "All failed subtests in $grp are known issues; propagating TODO directive to the top-level");
                $line = "ok $num selftests: $suite_group: $sub_group # TODO Known issue";
            }
        }

        push @updated_lines, $line;
    }

    my $tmp_file = "/tmp/updated_tap.$$";
    script_output("cat <<'EOF' > $tmp_file\n" . join("\n", @updated_lines) . "\nEOF");
    assert_script_run("mv $tmp_file $tap_file");

    parse_extra_log(KTAP => $tap_file);
}

sub run {
    my ($self) = @_;

    select_serial_terminal;
    record_info('KERNEL VERSION', script_output('uname -a'));

    my $collection = get_required_var('KSELFTESTS_COLLECTION');
    my $timeout = get_var('KSELFTEST_TIMEOUT', 45);    # Individual timeout for each test in the collection

    if (get_var('KSELFTEST_FROM_GIT', 0)) {
        install_from_git($collection);
        assert_script_run("cd ./tools/testing/selftests/kselftest_install");
    } else {
        install_from_ibs($collection);
        assert_script_run("cd /usr/share/kselftests");
    }

    # At this point, CWD has the file 'kselftest-list.txt' listing all the available tests
    # Since we only installed a single collection, it is the one that will be executed

    my @tests = split(/\n/, script_output('./run_kselftest.sh --list'));
    my $tests = '';
    my @skip = split /,/, get_var('KSELFTESTS_SKIP', '');
    if (@skip) {
        my %skip = map { $_ => 1 } @skip;
        # Remove tests that are in @skip
        @tests = grep { !$skip{$_} } @tests;
        $tests .= "--test $_ " for @tests;
    }

    assert_script_run("./run_kselftest.sh -o $timeout $tests > kselftest.tap", 7200);
    $self->postprocess_results($collection, "kselftest.tap");
}

1;
