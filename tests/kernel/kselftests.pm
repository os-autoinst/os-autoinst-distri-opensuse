# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Executes kselftests
# Maintainer: Kernel QE <kernel-qa@suse.de>

use base 'opensusebasetest';

use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use registration;
use utils;
use LTP::WhiteList;
use LTP::kirk;
use LTP::utils;

sub run_tests
{
    my ($root) = @_;

    my $env = prepare_whitelist_environment();
    $env->{kernel} = script_output('uname -r');

    my $issues = get_var('KSELFTESTS_KNOWN_ISSUES', '');
    my $whitelist = LTP::WhiteList->new($issues);
    my @skipped = $whitelist->list_skipped_tests($env, 'kselftests');
    my $skip_tests;
    if (@skipped) {
        $skip_tests = join("|", @skipped);

        record_info(
            "Exclude",
            "Excluding tests: $skip_tests",
            result => 'softfail'
        );
    }

    my @volumes = (
        {src => $root, dst => $root},
        {src => "/tmp", dst => "/tmp"}
    );

    my $suite = get_var('KSELFTESTS_SUITE', '');

    LTP::kirk->run(
        framework => "kselftests:root=$root",
        skip => $skip_tests,
        suite => $suite,
        # when KIRK_INSTALL == 'container' we want to share
        # kselftests folder and kirk logs folder
        container_volumes => \@volumes,
    );
}

sub run
{
    select_serial_terminal;

    my $repo = get_var('KSELFTESTS_REPO', '');
    my $suite = get_var('KSELFTESTS_SUITE', '');

    zypper_call("ar -f $repo kselftests");
    zypper_call("--gpg-auto-import-keys ref");

    zypper_call("install -y kselftests-$suite");
    run_tests("/usr/share/kselftests");
}

1;
