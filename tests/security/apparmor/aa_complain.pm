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

# Summary: Test AppArmor complain mode.
# - Creates a temporary profile dir in /tmp
# - Sets usr.bin.nscd in complain mode using command
# "aa-complain usr.sbin.nscd" and "aa-complain -d $aa_tmp_prof usr.sbin.nscd",
# validates output of command and take a screenshot of each command
# - Put nscd back in enforce mode
# - Cleanup temporary directories
# Maintainer: Wes <whdu@suse.com>
# Tags: poo#36880, tc#1621142

use strict;
use warnings;
use base "consoletest";
use testapi;
use utils;
use services::apparmor;

sub run {
    select_console 'root-console';
    services::apparmor::check_aa_complain();
}

1;
