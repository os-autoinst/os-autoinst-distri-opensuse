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
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use base "basetest";
use strict;
use testapi;
use virtmanager;

sub run {
    ensure_installed("virt-manager");
    # enable all view options
    launch_virtmanager();
    # go to preferences
    send_key "alt-e";
    send_key "p", 1;
    # go to polling
    send_key "right";
    for (1 .. 3) { send_key "tab"; }
    save_screenshot;
    # activate disk I/O
    send_key "spc"; sleep 1;
    send_key "tab";
    # acrtivate net I/O
    send_key "spc"; sleep 1;
    send_key "tab";
    # activate Mem stat
    send_key "spc"; sleep 1;
    # close preferences
    send_key "alt-c";
    send_key "esc"; sleep 1;

    # go to view now
    send_key "alt-v", 1;
    send_key "right", 1;
    # activate everything
    for (1 .. 4) {
	send_key "down";
	send_key "spc"; sleep 1
    }
    
    if (get_var("DESKTOP") ne "icewm") {
	assert_screen "virtman-sle12-gnome_viewcheck", 30;
    } else {
	# this should be icewm desktop, with a very basic gnome theme
	assert_screen "virtman-viewcheck", 30;
    }
    # close every opne windows
    send_key "esc";
    send_key "alt-f", 1;
    send_key "q";
    # close the xterm
    send_key "alt-f4";
}

sub test_flags {
    # without anything - rollback to 'lastgood' snapshot if failed
    # 'fatal' - whole test suite is in danger if this fails
    # 'milestone' - after this test succeeds, update 'lastgood'
    # 'important' - if this fails, set the overall state to 'fail'
    return { 'important' => 0, 'fatal' => 0, };
}

1;

# vim: set sw=4 et:
