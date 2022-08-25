# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate repos in the system using expectations from the test data.
#
# Maintainer: QE-YaST <qa-sle-yast@suse.de>

use strict;
use warnings;
use base "consoletest";
use testapi;
use repo_tools 'validate_repo_properties';
use scheduler 'get_test_suite_data';

sub run {
    my $test_data = get_test_suite_data();

    select_console 'root-console';

    script_output 'zypper -n lr --uri';

    foreach my $repo (@{$test_data->{repos}}) {
        my $filter = $repo->{filter} ? $repo->{$repo->{filter}} : undef;
        validate_repo_properties({
                Filter => $filter,
                Alias => $repo->{alias},
                Name => $repo->{name},
                URI => join('', /$repo->{uri}/),
                Enabled => $repo->{enabled},
                Autorefresh => $repo->{autorefresh}
        });
    }
}

1;
