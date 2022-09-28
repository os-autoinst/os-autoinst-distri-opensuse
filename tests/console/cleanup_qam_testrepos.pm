# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check and remove invalid test repositories
# * Run `zypper ref` on all test repositories on the test system
# * You can modify the behaviour on failing repos via the setting QAM_TESTREPO_FAIL:
#     - QAM_TESTREPO_FAIL=fail: Fail test (default)
#     - QAM_TESTREPO_FAIL=softfail: softfailure but resume
#     - QAM_TESTREPO_FAIL=clear: softfailure and remove failing repositories
#     - QAM_TESTREPO_FAIL=purge: remove failing repositories, no softfailure
#     - QAM_TESTREPO_FAIL=ignore: ignore all failures
# Maintainer: Felix Niederwanger <felix.niederwanger@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils;

sub get_repo_aliases() {
    # get repository names as string array
    assert_script_run("zypper lr -e repositories.repo");
    my $repos = script_output('cat repositories.repo | awk -F"[][]" \'{if ($2) print $2}\'');
    script_run("rm repositories.repo");
    return split("\n", "$repos");
}

sub run {
    my $self = shift;
    # If all repos are OK we don't have to do anything
    return if (script_retry('zypper -n ref', timeout => (is_public_cloud ? 1200 : 300), retry => 3, delay => 30, die => 0) == 0);

    my $behav = get_var('QAM_TESTREPO_FAIL') // "fail";
    # Check all repositories if they are valid
    foreach my $repo (get_repo_aliases()) {
        if (script_run("zypper -n ref '$repo'") != 0) {
            if ($behav eq "" || $behav eq "fail") {
                die "Repository $repo is invalid";
            } elsif ($behav eq "softfail") {
                record_info("repository $repo is invalid", result => 'softfail');
            } elsif ($behav eq "clear") {
                record_info("removing invalid repository: $repo", result => 'softfail');
                zypper_call("rr '$repo'");
            } elsif ($behav eq "purge") {
                record_info("removing invalid repository: $repo");
                zypper_call("rr '$repo'");
            } elsif ($behav eq "ignore") {
                record_info("repository $repo is invalid");
            } else {
                die "Unrecognised QAM_TESTREPO_FAIL";
            }
        }
    }
}


1;
