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
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use base "x11test";
use strict;
use testapi;
use utils;

sub run() {
    select_console 'x11';

    x11_start_program("xterm");
    assert_screen('xterm-started');
    assert_script_sudo "chown $testapi::username /dev/$testapi::serialdev";
    assert_script_sudo "echo \"download.use_deltarpm = false\" >> /etc/zypp/zypp.conf";
    assert_script_run "pkcon refresh";
    send_key "alt-f4";
}

sub test_flags() {
    return {fatal => 1, milestone => 1};
}

1;
# vim: set sw=4 et:
