# Copyright (C) 2014 SUSE Linux Products GmbH
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
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use strict;
use base 'basetest';
use testapi;

sub run {
    # wait for bootloader to appear
    assert_screen( "autoyast-boot", 300 );

    # select network (second entry)
    send_key "down";

    send_key "tab";

    if (get_var("AUTOYAST")) {
        my $proto= get_var("PROTO") || 'http';
    
        #edit parameters
	if (get_var("UPGRADE_FROM_AUTOYAST") || get_var("UPGRADE")) {
		type_string " autoupgrade=1";
	}
        type_string " autoyast=$proto://10.0.2.1/data/" . get_var("AUTOYAST");
        # type_string  get_var("AUTOYAST");
    }

#    type_string " Y2DEBUG=1";

    send_key "ret";

}

sub test_flags {
    # without anything - rollback to 'lastgood' snapshot if failed
    # 'fatal' - whole test suite is in danger if this fails
    # 'milestone' - after this test succeeds, update 'lastgood'
    # 'important' - if this fails, set the overall state to 'fail'
    return { important => 1, fatal => 1 };
}

1;

# vim: set sw=4 et:
