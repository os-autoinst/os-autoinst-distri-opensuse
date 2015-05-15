# Copyright (C) 2015 SUSE Linux Products GmbH
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
    my $self = shift;

    send_key "ctrl-alt-f4";
    assert_screen "text-login", 20;
    type_string "$username\n";
    if (!get_var("LIVETEST")) {
        assert_screen "password-prompt", 20;
        type_password;
        type_string "\n";
    }
    sleep 3;
    script_sudo "reboot";
    assert_screen "bios-boot", 100;

}

sub test_flags {
    # without anything - rollback to 'lastgood' snapshot if failed
    # 'fatal' - whole test suite is in danger if this fails
    # 'milestone' - after this test succeeds, update 'lastgood'
    # 'important' - if this fails, set the overall state to 'fail'
    return { important => 1 };
}

1;

# vim: set sw=4 et:
