# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Download repositores from the internal server
#
# Maintainer: qa-c <qa-c@suse.de>

use base 'consoletest';
use registration;
use warnings;
use testapi;
use strict;
use utils;
use qam;
use publiccloud::ssh_interactive "select_host_console";
use publiccloud::utils "validate_repo";

sub run {
    my ($self, $args) = @_;
    select_host_console();    # select console on the host, not the PC instance

    if (get_var('PUBLIC_CLOUD_SKIP_MU')) {
        # Skip maintenance updates. This is useful for debug runs
        record_info('Skip validation', 'Skipping maintenance update validation (triggered by setting)');
        return;
    } else {
        my @repos = get_test_repos();
        # Failsafe: Fail if there are no test repositories, otherwise we have the wrong template link
        my $count = scalar @repos;
        my $check_empty_repos = get_var('PUBLIC_CLOUD_IGNORE_EMPTY_REPO', 0) == 0;
        die "No test repositories" if ($check_empty_repos && $count == 0);

        my $repo_count = 0;
        my ($incident, $type);
        for my $maintrepo (@repos) {
            next unless validate_repo($maintrepo);
            $repo_count++;
        }
        die "No usable test repositories" if ($repo_count == 0);
    }
}

sub post_fail_hook {
}

sub test_flags {
    return {
        fatal => 1,
        milestone => 1,
        publiccloud_multi_module => 1
    };
}

1;
