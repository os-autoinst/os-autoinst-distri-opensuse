# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

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

    foreach my $repo (@{$test_data->{repos}}) {
        my $filter = $repo->{filter} ? $repo->{$repo->{filter}} : undef;
        validate_repo_properties({
                Filter      => $filter,
                Alias       => $repo->{alias},
                Name        => $repo->{name},
                URI         => $repo->{uri},
                Enabled     => $repo->{enabled},
                Autorefresh => $repo->{autorefresh}
        });
    }
}

1;
