# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Executes kselftests
# Maintainer: Kernel QE <kernel-qa@suse.de>

use base 'opensusebasetest';
use testapi qw(get_var get_required_var set_var);
use utils;
use strict;
use testapi;
use warnings;
use serial_terminal 'select_serial_terminal';
use LTP::WhiteList;

sub run
{
    my ($self) = @_;
    my $repo = get_var('LINUX_REPO', 'https://github.com/torvalds/linux');
    my $branch = get_var('LINUX_BRANCH', 'master');

    select_serial_terminal;

    # download linux source code
    zypper_call("in -y git");
    assert_script_run("git clone -q --single-branch -b $branch --depth 1 $repo");

    # install build tools and compile tests
    my $suite = get_required_var('KSELFTESTS_SUITE');
    my $root = "/root/linux/tools/testing/selftests";

    zypper_call("in -t pattern devel_basis");
    assert_script_run("make -C $root/$suite", timeout => 1800);

    # set tests to skip
    my $environment = {
        product => get_var('DISTRI') . ':' . get_var('VERSION'),
        revision => get_var('BUILD'),
        flavor => get_var('FLAVOR'),
        arch => get_var('ARCH'),
        backend => get_var('BACKEND'),
        kernel => script_output('uname -r'),
        libc => '',
        gcc => '',
        harness => 'SUSE OpenQA',
        ltp_version => ''
    };

    my $issues = get_var('KSELFTESTS_KNOWN_ISSUES', '');
    my $whitelist = LTP::WhiteList->new($issues);
    my @skipped = $whitelist->list_skipped_tests($environment, 'kselftests');
    if (@skipped) {
        my $test_exclude = join("|", @skipped);

        record_info(
            "Exclude",
            "Excluding tests: $test_exclude",
            result => 'softfail'
        );

        set_var('KIRK_SKIP', "$test_exclude");
    }

    # setup kirk framework before calling it
    set_var('KIRK_FRAMEWORK', "kselftests:root=$root");
    set_var('KIRK_SUITE', "$suite");
}

1;
