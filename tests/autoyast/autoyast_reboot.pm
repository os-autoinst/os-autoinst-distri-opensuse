# Copyright (C) 2015-2016 SUSE LLC
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

# Summary: Reboot for autoyast scenarios
# Maintainer: Pavel Sladek <psladek@suse.cz>

use strict;
use base 'basetest';
use testapi;

sub run {
    type_string("shutdown -r now\n");
    reset_consoles;

    #obsoletes installation/autoyast_reboot.pm
    assert_screen("bios-boot",     900);
    assert_screen("autoyast-boot", 20);
}

sub test_flags {
    return {important => 1};
}

1;

# vim: set sw=4 et:
