# Copyright (C) 2018-2021 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.
#
# Package: apparmor-utils apparmor-parser
# Summary: Test the basic information output function for apparmor using
# aa-status.
# - Check if apparmor is active
# - Run aa-status, check the output for strings about modules/profiles/processes
#   and verify "aa-status" can "handle profile with name contains '('".
# and strings enforced, complain, unconfined and loaded.
# Maintainer: llzhao <llzhao@suse.com>
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
    my $testfile    = "/usr/bin/ls";
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
