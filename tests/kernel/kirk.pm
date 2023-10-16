# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Executes kirk testing framework
# Maintainer: Kernel QE <kernel-qa@suse.de>

use base 'opensusebasetest';
use testapi qw(get_var get_required_var);
use utils;
use strict;
use testapi;
use warnings;
use serial_terminal 'select_serial_terminal';
use version_utils qw(is_transactional);
use transactional 'trup_install';
use LTP::utils;

our $result_file = 'result.json';

sub run
{
    my ($self) = @_;
    my $install_from = get_var('KIRK_INSTALL', 'repo');
    my $repo = get_var('KIRK_REPO', 'https://github.com/acerv/kirk.git');
    my $branch = get_var('KIRK_BRANCH', 'master');
    my $timeout = get_var('KIRK_TIMEOUT', '5400');
    my $framework = get_required_var('KIRK_FRAMEWORK');
    my $sut = get_var('KIRK_SUT', 'host');
    my $skip = get_var('KIRK_SKIP', '');
    my $envs = get_var('KIRK_ENVS', '');
    my $opts = get_var('KIRK_OPTIONS', '');
    my $suite = get_var('KIRK_SUITE', '');

    select_serial_terminal;
    zypper_call("ref");

    my $cmd = '';
    if ($install_from =~ /git/i) {
        is_transactional ? trup_install("git") : zypper_call("in -y git");
        assert_script_run("git clone -q --single-branch -b $branch --depth 1 $repo");

        $cmd = "python3 kirk/kirk ";
    } else {
        add_ltp_repo();
        is_transactional ? trup_install("kirk") : zypper_call("in -y kirk");

        $cmd = 'kirk ';
    }

    $cmd .= "--verbose ";
    $cmd .= "--suite-timeout $timeout ";
    $cmd .= "--json-report $result_file ";
    $cmd .= "--framework $framework " if $framework;
    $cmd .= "--sut $sut " if $sut;
    $cmd .= "--skip-tests $skip " if $skip;
    $cmd .= "--env $envs " if $envs;
    $cmd .= "--run-suite $suite " if $suite;
    $cmd .= "$opts " if $opts;

    assert_script_run($cmd, timeout => $timeout);
}

sub upload_kirk_logs
{
    my ($self) = @_;

    assert_script_run("test -f /tmp/kirk.\$USER/latest/debug.log || echo No debug log");
    upload_logs("/tmp/kirk.\$USER/latest/debug.log", failok => 1);

    parse_extra_log('LTP', $result_file);
}

sub post_run_hook
{
    upload_kirk_logs;
}

sub post_fail_hook
{
    upload_kirk_logs;
}

1;
