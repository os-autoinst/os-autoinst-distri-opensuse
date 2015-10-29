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
use ttylogin;

sub run {
    ttylogin ('4', "root");
    if ( get_var("CLEAN_UDEV") ) {
        type_string "rm -f /etc/udev/rules.d/70-persistent-net.rules\n";
    }
    if ( get_var("SYSTEMD_TARGET") ) {
        type_string "systemctl set-default " . get_var("SYSTEMD_TARGET") . "\n";
        type_string "systemctl status default.target\n";
        type_string "systemctl mask packagekit.service\n";
        type_string "systemctl stop packagekit.service\n";
        save_screenshot;
        type_string "zypper -n rm plymouth\n";
        wait_idle ;
        save_screenshot;
        type_string "mkinitrd\n";
        wait_idle ;
        save_screenshot;
    }
    type_string "poweroff\n";
    assert_shutdown;
}

sub test_flags {
    return { fatal => 1 };
}

1;

# vim: set sw=4 et:
