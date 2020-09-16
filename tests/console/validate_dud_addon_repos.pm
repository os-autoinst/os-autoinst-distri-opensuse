# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Validate that DUD addon repos activated during the installation are
# properly added and enabled. Also, verifies that 'zypper ref' works and all the
# repositories can be refreshed.
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use base 'consoletest';
use strict;
use warnings;

use testapi;
use repo_tools 'validate_repo_properties';
use scheduler 'get_test_suite_data';

sub run {
    my $test_data = get_test_suite_data;
    select_console 'root-console';

    foreach my $repo (keys %{$test_data->{dud_repos}}) {
        validate_repo_properties({
                URI => 'ftp://' . get_required_var('OPENQA_HOSTNAME') . '/' .
                  get_required_var($repo),
                Enabled     => $test_data->{dud_repos}->{$repo}->{Enabled},
                Autorefresh => $test_data->{dud_repos}->{$repo}->{Autorefresh}
        });
    }
    assert_script_run('zypper -v ref | grep "All repositories have been refreshed"', 120);
}

1;
