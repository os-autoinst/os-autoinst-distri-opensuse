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

sub run() {
    ensure_installed('vlc');
    x11_start_program("vlc --no-autoscale");
    assert_screen "vlc-first-time-wizard";
    send_key "ret";
    assert_screen "vlc-main-window";
    send_key "ctrl-l";
    assert_and_click "vlc-playlist-empty";
    send_key "ctrl-n";
    assert_screen "vlc-network-window";
    send_key "backspace";
    type_string autoinst_url . "/data/Big_Buck_Bunny_8_seconds_bird_clip.ogv";
    send_key "alt-p";
    send_key "ret";
    assert_screen "vlc-done-playing";
    send_key "ctrl-q";
}

1;
# vim: set sw=4 et:
