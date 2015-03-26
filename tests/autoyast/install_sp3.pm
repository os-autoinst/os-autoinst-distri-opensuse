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

sub is_applicable {
    return get_var("UPGRADE_FROM_AUTOYAST"); # check for $ENV{SOMETHING}
}

sub run {
    # wait for bootloader to appear
    check_screen( "autoyast-boot", 300 ) or die "sp3 install failed";

    # select sp3 (3rd entry)
    send_key "down";
    send_key "down";

    #edit parameters
    send_key "tab";
    type_string " autoyast=get_var("UPGRADE_FROM_AUTOYAST")";
    send_key "ret";
    
    check_screen( "autoyast-system-login-sp3", 2000 ) or die "sp3 install failed";
    type_string "root\n";
    sleep 15;
    type_string "root\n";
    sleep 1;
#    type_string "mkdir -p /etc/zypp/credentials.d\n"; #workaround for 884384
#    type_string "rpm -e puppet\n"; #workaround for uninstallable puppet on build 496
    
    type_string "shutdown -r now\n";

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
