# Copyright (C) 2020 SUSE LLC
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
#
# Summary: The Battle for Wesnoth game test
# Maintainer: Christian Lanig <clanig@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;

sub run {
    select_console "x11";
    ensure_installed "wesnoth";
    x11_start_program "wesnoth";
    wait_still_screen 1;

    # Double click necessary to achieve fullscreen window focus
    assert_and_dclick "wesnoth-preferences";
    assert_and_click "wesnoth-preferences-display";
    assert_and_click "wesnoth-preferences-unit-standing-anim";
    assert_and_click "wesnoth-preferences-display-idle-anim";
    assert_and_click "wesnoth-preferences-close";
    assert_and_dclick "wesnoth-campaign-button";
    assert_and_click "wesnoth-campaign-brothers-select";
    assert_and_click "wesnoth-play-btn";
    assert_and_click "wesnoth-difficulty-confirm";
    assert_and_click "wesnoth-skip-btn";
    assert_screen "wesnoth-ingame";

    # Skip dialogue
    for (1 .. 11) {
        click_lastmatch;
    }

    assert_and_click "wesnoth-menu";
    assert_and_click "wesnoth-save-game";
    assert_and_click "wesnoth-save-btn";
    assert_and_click "wesnoth-save-confirm";
    assert_and_click "wesnoth-horseman";
    assert_and_click "wesnoth-camp";
    assert_screen "wesnoth-horseman-on-camp";
    assert_and_click "wesnoth-fortress-field", button => "right";
    assert_and_click "wesnoth-recruit";
    assert_and_click "wesnoth-recruit-btn";
    assert_screen "wesnoth-new-archer";
    send_key "ctrl-o";
    send_key "ret";
    assert_screen "wesnoth-camp";
    assert_and_click "wesnoth-endturn";
    assert_and_click "wesnoth-confirm-endturn";
    assert_screen "wesnoth-night", 30;
    send_key "ctrl-q";
    send_key "ret";
    send_key "ctrl-q";
}
1;
