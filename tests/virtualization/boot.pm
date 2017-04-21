# Copyright (C) 2014 SUSE Linux GmbH
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

# Summary: - add the virtualization test suite- add a load_virtualization_tests call
# Maintainer: aginies <aginies@suse.com>

use base "basetest";
use strict;
use testapi;

sub run {
    # wait for bootloader to appear
    assert_screen "SLE12_bootloader", 25;
    # press enter to boot right away
    send_key "down";
    send_key "ret";
    save_screenshot;
}

1;

# vim: set sw=4 et:
