# Copyright (C) 2018 SUSE LLC
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
# Summary: Set an AppArmor profile for nscd in to complain mode, check 2 modes (default
# location and location specified. Save screenshot for each scenario for later
# checking.
# Maintainer: Wes <whdu@suse.com>
# Tags: poo#36880, tc#1621142

use strict;
use warnings;
use base "consoletest";
use testapi;
use utils;

sub run {

    my $aa_tmp_prof = "/tmp/apparmor.d";

    # Test both situation for default profiles location and the location
    # specified with '-d'
    my @aa_complain_cmds = ("aa-complain usr.sbin.nscd", "aa-complain -d $aa_tmp_prof usr.sbin.nscd");

    select_console 'root-console';

    systemctl('restart apparmor');

    assert_script_run "cp -r /etc/apparmor.d $aa_tmp_prof";

    foreach my $cmd (@aa_complain_cmds) {
        validate_script_output $cmd, sub {
            m/Setting.*nscd to complain mode/s;
        };
        save_screenshot;

        # Restore to the enforce mode
        assert_script_run "aa-enforce usr.sbin.nscd";
    }

    # Clean Up
    assert_script_run "rm -rf $aa_tmp_prof";

}

1;
