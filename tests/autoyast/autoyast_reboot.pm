# Copyright (C) 2015-2017 SUSE LLC
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
use utils;

sub run {
    # Kill ssh proactively before reboot to avoid half-open issue on zVM
    prepare_system_shutdown;

    type_string("shutdown -r now\n");
    reset_consoles;

    # We have to reconnect in next on zVM
    if (check_var("BACKEND", "s390x")) {
        return;
    }

    assert_screen("bios-boot",  900);
    assert_screen("bootloader", 30);

    if (check_var("BOOTFROM", "d")) {
        assert_screen("inst-bootmenu", 60);
    }
}

1;

# vim: set sw=4 et:
