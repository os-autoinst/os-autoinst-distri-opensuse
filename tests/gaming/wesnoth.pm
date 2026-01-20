# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: The Battle for Wesnoth game test
# Maintainer: Christian Lanig <clanig@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;

sub run {
    select_console "x11";
    ensure_installed "wesnoth", timeout => 600;
    x11_start_program "wesnoth";

    # Double click necessary to achieve focus on window
    assert_and_click "wesnoth-preferences";
    assert_and_click "wesnoth-preferences-display";
    assert_and_click "wesnoth-preferences-display-anim-map";
    assert_and_click "wesnoth-preferences-unit-standing-anim";
    assert_and_click "wesnoth-preferences-display-idle-anim";
    assert_and_click "wesnoth-preferences-close";
    assert_and_click "wesnoth-campaign-button";
    assert_and_click "wesnoth-campaign-brothers-select";
    assert_and_click "wesnoth-play-btn";
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

    # Sometimes mouse lands on the border shifting the displayed map area
    mouse_set(100, 100);

    # Focus display on lead figure
    send_key "l";

    assert_and_click "wesnoth-horseman";
    assert_and_click "wesnoth-camp";
    assert_screen "wesnoth-horseman-on-camp";
    assert_and_click "wesnoth-fortress-field", button => "right";
    assert_and_click "wesnoth-recruit";
    assert_and_click "wesnoth-recruit-btn";
    assert_screen "wesnoth-new-archer";
    assert_and_click "wesnoth-menu";
    assert_and_click "wesnoth-load-btn";
    assert_and_click "wesnoth-load-confirm";

    # Focus display on lead figure
    send_key "l";

    assert_screen "wesnoth-camp";
    assert_and_click "wesnoth-endturn";
    assert_and_click "wesnoth-confirm-endturn";
    assert_screen "wesnoth-night";
    assert_and_click "wesnoth-menu";
    assert_and_click "wesnoth-menu-quit-to-desktop";
    assert_and_click "wesnoth-menu-quit-to-desktop-confirm";
}
1;
