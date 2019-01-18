# Copyright (C) 2014-2017 SUSE LLC
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

use base 'x11test';
use strict;
use warnings;
use testapi;
use virtmanager;

sub run {
    # enable all view options
    launch_virtmanager();
    # go to preferences
    wait_screen_change { send_key 'alt-e' };
    send_key 'p';
    assert_screen 'virtman-preferences';
    # go to polling
    wait_screen_change { send_key 'right' };
    for (1 .. 3) { send_key 'tab' }
    assert_screen 'virtman-polling';
    # activate disk I/O
    wait_screen_change { send_key 'spc' };
    send_key 'tab';
    # acrtivate net I/O
    wait_screen_change { send_key 'spc' };
    send_key 'tab';
    # activate Mem stat
    wait_screen_change { send_key 'spc' };
    # close preferences
    send_key 'alt-c';
    wait_screen_change { send_key 'esc' };

    # go to view now
    wait_screen_change { send_key 'alt-v' };
    wait_screen_change { send_key 'right' };
    # activate everything
    for (1 .. 4) {
        send_key 'down';
        wait_screen_change { send_key 'spc' };
    }
    assert_screen 'virtman-viewcheck';
    # close every open windows
    wait_screen_change { send_key 'esc' };
    wait_screen_change { send_key 'alt-f' };
    wait_still_screen(1);
    wait_screen_change { send_key 'q' };
    # close the xterm
    send_key 'alt-f4';
}

1;

