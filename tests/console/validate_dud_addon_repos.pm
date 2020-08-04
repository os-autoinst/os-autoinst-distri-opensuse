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
use repo_tools 'parse_repo_data';
use scheduler 'get_test_suite_data';
use Test::Assert ':all';

sub run {
    my $test_data = get_test_suite_data();
    select_console 'root-console';
    foreach my $expected_dud_repo (@{$test_data->{dud_repos}}) {
        my $actual_dud_repo = parse_repo_data($expected_dud_repo->{URI});
        assert_equals($expected_dud_repo->{Enabled}, $actual_dud_repo->{Enabled},
            "Fail! It is expected that the 'Enabled' field is set to $expected_dud_repo->{Enabled}, but it is $actual_dud_repo->{Enabled}");
        assert_equals($expected_dud_repo->{Autorefresh}, $actual_dud_repo->{Autorefresh},
            "Fail! It is expected that the 'Autorefresh' field is set to $expected_dud_repo->{Autorefresh}, but it is $actual_dud_repo->{Autorefresh}");
    }
    assert_script_run('zypper -v ref | grep "All repositories have been refreshed"', 120);
}

1;
