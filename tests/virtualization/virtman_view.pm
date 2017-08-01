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

# Summary: Basic test of virtman features
# Maintainer: Antoine <aginies@suse.com>

use base "x11test";
use strict;
use testapi;
use virtmanager;

sub run {
    # enable all view options
    launch_virtmanager();
    # go to preferences
    send_key "alt-e";
    wait_still_screen;
    wait_screen_change { send_key "p" };
    # go to polling
    send_key "right";
    for (1 .. 3) { send_key "tab"; }
    save_screenshot;
    # activate disk I/O
    wait_screen_change {
        send_key "spc";
    };
    send_key "tab";
    # acrtivate net I/O
    send_key "spc";
    sleep 1;
    send_key "tab";
    # activate Mem stat
    send_key "spc";
    sleep 1;
    # close preferences
    send_key "alt-c";
    send_key "esc";
    sleep 1;

    # go to view now
    wait_screen_change { send_key "alt-v" };
    wait_screen_change { send_key "right" };
    # activate everything
    for (1 .. 4) {
        send_key "down";
        send_key "spc";
        sleep 1;
    }

    if (get_var("DESKTOP") !~ /icewm/) {
        assert_screen "virtman-sle12-gnome_viewcheck", 30;
    }
    else {
        # this should be icewm desktop, with a very basic gnome theme
        assert_screen "virtman-viewcheck", 30;
    }
    # close every open windows
    wait_screen_change {
        send_key "esc";
    };
    wait_screen_change {
        send_key "alt-f";
    };
    wait_still_screen;
    wait_screen_change {
        send_key "q";
    };
    # close the xterm
    send_key "alt-f4";
}

1;

# vim: set sw=4 et:
