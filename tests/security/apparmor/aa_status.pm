# Copyright 2018-2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: apparmor-utils apparmor-parser
# Summary: Test the basic information output function for apparmor using
# aa-status.
# - Check if apparmor is active
# - Run aa-status, check the output for strings about modules/profiles/processes
#   and verify "aa-status" can "handle profile with name contains '('".
# and strings enforced, complain, unconfined and loaded.
# Maintainer: QE Security <none@suse.de>
# Tags: tc#1767574, poo#81727, poo#36874, poo#44912

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use services::apparmor;
use apparmortest qw(create_a_test_profile aa_status_stdout_check);
use version_utils qw(is_leap is_sle);

sub run {
    my ($self) = @_;

    select_console 'root-console';
    services::apparmor::check_service();
    services::apparmor::check_aa_status();

    # Verify "aa-status" can "handle profile with name contains '('"
    my $testfile = "/usr/bin/ls";
    my $str_special = '\(test\)';

    if (!is_sle("<15-sp3") && !is_leap("<15.3")) {
        apparmortest::create_a_test_profile_name_is_special($testfile, $str_special);
        systemctl("restart apparmor");
        services::apparmor::check_aa_status();
        validate_script_output 'aa-status', sub { m/.*$str_special.*/ };
        apparmortest::aa_tmp_prof_clean($self, "$testfile" . "$str_special");
        apparmortest::aa_tmp_prof_clean($self, "/etc/apparmor.d/.*$str_special.*");
    }
}

1;
