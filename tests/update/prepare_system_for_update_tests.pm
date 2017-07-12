# Copyright (C) 2016 SUSE LLC
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

# Summary: Prepare system for actual desktop specific updates
# Maintainer: Stephan Kulow <coolo@suse.de>

use base "consoletest";
use strict;
use testapi;
use utils;

sub run {
    select_console 'root-console';

    assert_script_run "chown $testapi::username /dev/$testapi::serialdev";
    assert_script_run "echo \"download.use_deltarpm = false\" >> /etc/zypp/zypp.conf";
    assert_script_run "systemctl unmask packagekit";
    assert_script_run "pkcon refresh", 90;
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
# vim: set sw=4 et:
