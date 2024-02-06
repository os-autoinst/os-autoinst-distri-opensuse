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
use publiccloud::ssh_interactive "select_host_console";
use publiccloud::utils "validate_repo";

sub run {
    my ($self, $args) = @_;
    select_host_console();    # select console on the host, not the PC instance

    if (get_var('PUBLIC_CLOUD_SKIP_MU')) {
        # Skip maintenance updates. This is useful for debug runs
        record_info('Skip validation', 'Skipping maintenance update validation (triggered by setting)');
        return;
    }
    # In Incidents there is INCIDENT_REPO instead of MAINT_TEST_REPO
    # Those two variables contain list of repositories separated by comma
    set_var('MAINT_TEST_REPO', get_var('INCIDENT_REPO')) unless get_var('MAINT_TEST_REPO');
    my @repos = split(/,/, get_var('MAINT_TEST_REPO'));
    # Failsafe: Fail if there are no test repositories, otherwise we have the wrong template link
    die "No test repositories" if (scalar @repos == 0);

    my $repo_count = 0;
    my ($incident, $type);
    for my $maintrepo (@repos) {
        next unless validate_repo($maintrepo);
        $repo_count++;
    }
    die "No usable test repositories" if ($repo_count == 0);
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
