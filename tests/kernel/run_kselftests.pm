# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Executes kselftests.
# This module introduces openqa runner for kernel selftests
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
use LTP::utils;

sub run_tests_from_git_repo
{
    my ($root) = @_;

    my $git_tree = get_required_var('KERNEL_GIT_TREE');

    # download, compile and install a kernel tree from git
    zypper_call('in bc git-core ncurses-devel gcc flex bison libelf-devel libopenssl-devel');
    # git clone takes a long time due to slow network connection
    assert_script_run("git clone --depth 1 --single-branch --branch master $git_tree linux", 7200);
}

sub run_tests
{
    my ($root) = @_;

    my $env = prepare_whitelist_environment();
    $env->{kernel} = script_output('uname -r');

    my $kselftests_suite = get_var('KSELFTESTS_SUITE', '');
    my $known_issues = get_var('KSELFTESTS_KNOWN_ISSUES', '');
    my $whitelist = LTP::WhiteList->new($known_issues);
    my @skipped = $whitelist->list_skipped_tests($env, $kselftests_suite);
    my $skip_tests;
    if (@skipped) {
        $skip_tests = join("|", @skipped);

        record_info(
            "Exclude",
            "Excluding tests: $skip_tests",
            result => 'softfail'
        );
    }

    assert_script_run("TARGETS=$kselftests_suite /usr/share/kselftests/run_kselftest.sh");
    assert_script_run("TARGETS=$kselftests_suite /usr/share/kselftests/run_kselftest.sh -s > overview.log");

    #script_run('wget --quiet ' . data_url('kernel/kselftests_cgroup_post_process') . ' -O post_process');
    #script_run('chmod +x post_process');
    #script_run('./kselftests_cgroup_post_process');

}

sub run
{
    select_serial_terminal;

    my $kselftest_git = get_var('KSELFTEST_GIT', 0);
    my $repo = get_var('KSELFTESTS_REPO', '');
    my $suite = get_var('KSELFTESTS_SUITE', '');

    zypper_call("ar -f $repo kselftests");
    zypper_call("--gpg-auto-import-keys ref");

    zypper_call("install -y kselftests-$suite");

    if (get_var('KSELFTEST_GIT')) {
        run_tests_from_git_repo();
        sleep(99999);
    } else {
        run_tests("/usr/share/kselftests");
    }
}

1;
