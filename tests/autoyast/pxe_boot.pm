# Copyright (C) 2015 SUSE Linux GmbH
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

# Summary: PXE boot with autoyast profile
# Maintainer: Pavel Sladek <psladek@suse.cz>

use strict;
use base 'basetest';
use testapi;
use lockapi;

sub run {
    mutex_lock('pxe');
    mutex_unlock('pxe');
    resume_vm();

    # wait for bootloader to appear
    assert_screen("autoyast-boot", 300);

    # select network (second entry)
    send_key "down";

    send_key "tab";

    type_string "  ";    #need to separate default params
    type_string "vga=791 ";
    if (get_var("Y2DEBUG")) {
        type_string "Y2DEBUG=" . get_var("Y2DEBUG") . " ";
    }
    type_string "video=1024x768-16 ", 13;

    if (get_var("AUTOYAST")) {
        my $proto = get_var("PROTO") || 'http';

        #edit parameters
        if (get_var("UPGRADE_FROM_AUTOYAST") || get_var("UPGRADE")) {
            type_string " autoupgrade=1";
        }
        if (get_var("AUTOYAST") =~ /^aytests\//) {
            # test from aytests package
            type_string " autoyast=$proto://10.0.2.1/" . get_var("AUTOYAST");
        }
        else {
            # test from re-exported data directory
            type_string " autoyast=$proto://10.0.2.1/data/" . get_var("AUTOYAST");
        }
    }
    if (get_var("EXTRA_BOOT_ARG")) {
        type_string(' ' . get_var("EXTRA_BOOT_ARG"));
    }

    sleep 3;
    save_screenshot;
    send_key "ret";

}

sub test_flags {
    # without anything - rollback to 'lastgood' snapshot if failed
    # 'fatal' - whole test suite is in danger if this fails
    # 'milestone' - after this test succeeds, update 'lastgood'
    # 'important' - if this fails, set the overall state to 'fail'
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
