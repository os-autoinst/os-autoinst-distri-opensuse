## Copyright 2025 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Arrange Agama in order to be able to run the test scenario.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi qw(
  assert_script_run
  data_url
  get_var
  get_required_var
  record_info
  script_run
  send_key
  select_console
  wait_still_screen
);
use autoyast qw(expand_agama_profile);

sub run {
    # https://bugzilla.suse.com/show_bug.cgi?id=1237056
    sleep 10;

    # import Agama profile to arrange the system at a point where there is already
    # sufficient test coverage as a shorcut or in some cases for adding a workaround
    if (my $agama_test = get_var('AGAMA_PROFILE')) {
        record_info('import yes', "Profile import is performed.");
        my $profile = expand_agama_profile(get_var('AGAMA_PROFILE'));
        select_console 'root-console';
        script_run("dmesg --console-off");
        assert_script_run("agama profile import $profile", timeout => 300);
        script_run("dmesg --console-on");
    }
    else {
        record_info('import no', "No profile import is performed.");
    }

    # patch Agama on Live Medium using yupdate copying integration test from GitHub
    if (my $agama_test = get_var('AGAMA_TEST')) {
        record_info('test yes', "External files are fetched for testing.");
        select_console 'root-console';
        my ($repo, $branch) = split(/#/, get_required_var('YUPDATE_GIT'));
        assert_script_run("AGAMA_TEST=" . get_var('AGAMA_TEST') . " yupdate patch $repo $branch", timeout => 60);
    }
    else {
        record_info('test no', "No external files are fetched for testing.");
    }
}

1;
