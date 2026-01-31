# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate that DUD addon repos activated during the installation are
# properly added and enabled. Also, verifies that 'zypper ref' works and all the
# repositories can be refreshed.
#
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'consoletest';

use testapi;
use repo_tools 'validate_repo_properties';
use scheduler 'get_test_suite_data';

sub run {
    my $test_data = get_test_suite_data();
    select_console 'root-console';

    foreach my $repo (keys %{$test_data->{dud_repos}}) {
        validate_repo_properties({
                URI => 'ftp://' . get_required_var('OPENQA_HOSTNAME') . '/' .
                  get_required_var($repo),
                Enabled => $test_data->{dud_repos}->{$repo}->{Enabled},
                Autorefresh => $test_data->{dud_repos}->{$repo}->{Autorefresh}
        });
    }
    assert_script_run('zypper ref', timeout => 180);
}

1;
