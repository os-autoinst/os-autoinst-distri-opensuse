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

# G-Summary: supportserver and supportserver generator implementation
# G-Maintainer: Pavel Sladek <psladek@suse.com>

use strict;
use base 'basetest';
use testapi;

sub run {
    # the supportserver image can be different version than the currently tested system
    # so try to login without use of needles
    #
    if (get_var("SUPPORTSERVER_NEEDLE_LOGIN")) {
        #fallback to needle based detection, if serial console not set or not supported
        assert_screen("autoyast-system-login-console", 200);
    }
    else {
        wait_serial("login:", 200);
    }

    type_string "root\n";
    sleep 1;
    wait_idle(10);
    type_password;
    type_string "\n";

    type_string "echo LOK >/dev/$serialdev";
    send_key "ret";
    wait_serial("LOK", 100);

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
