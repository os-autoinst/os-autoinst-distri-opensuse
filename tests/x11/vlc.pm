# Copyright (C) 2016-2019 SUSE LLC
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

# Package: vlc
# Summary: Play some free video file with VLC
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "x11test";
use strict;
use warnings;
use testapi;

sub run {
    ensure_installed('vlc');
    x11_start_program('vlc --no-autoscale', target_match => 'vlc-first-time-wizard');
    assert_and_click "vlc-first-time-wizard";
    assert_screen "vlc-main-window";
    send_key_until_needlematch("vlc-playlist-empty", "ctrl-l", 3, 60);
    send_key_until_needlematch("vlc-network-window", "ctrl-n", 3, 60);
    send_key "backspace";
    type_string autoinst_url . "/data/Big_Buck_Bunny_8_seconds_bird_clip.ogv";
    assert_screen "url_check", 90;
    assert_and_click "vlc-play_button";
    # The video is actually 23 seconds long so give a bit of headroom for
    # startup
    assert_screen([qw(vlc-done-playing vlc-stuck-never-played)], 90);
    if (match_has_tag('vlc-stuck-never-played')) {
        record_soft_failure 'boo#1102838';
        x11_start_program('killall -9 vlc', valid => 0);
    }
    else {
        wait_still_screen(1);
        assert_and_click 'close_vlc';
    }

    if (!check_var('QEMUVGA', 'cirrus')) {
        x11_start_program('vlc --no-autoscale --loop data/test.ogv', target_match => 'vlc-playing');
        assert_and_click 'close_vlc';
    }
}

1;
