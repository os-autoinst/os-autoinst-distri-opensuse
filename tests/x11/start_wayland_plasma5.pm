# SUSE's openQA tests
#
# Copyright 2017-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: plasma5-session-wayland/plasma6-session
# Summary: Prepare for wayland and log out of X11 and into wayland
# Maintainer: Fabian Vogt <fvogt@suse.com>

use Mojo::Base 'x11test';
use testapi;
use utils;
use x11utils qw(handle_login update_x11_vt);

sub run {
    my ($self) = @_;

    # Log out of X session
    send_key 'super';    # Open the application menu

    # Logout in kicker and kickoff is different
    assert_screen(["desktop_mainmenu-kicker", "desktop_mainmenu-kickoff"]);
    if (match_has_tag('desktop_mainmenu-kicker')) {
        assert_and_click 'plasma_logout_btn';    # Click on the logout button
    }
    elsif (match_has_tag('desktop_mainmenu-kickoff')) {
        assert_and_click 'plasma_kickoff_leave';    # Switch to the leave section
        assert_and_click 'plasma_kickoff_logout';    # Click on the logout button
    }

    assert_and_click 'plasma_overlay_confirm';    # Confirm logout

    # Now we're in sddm
    assert_and_click 'sddm_desktopsession';    # Open session selection box
    assert_and_click 'sddm_session_plasma_wayland';    # Select Plasma 5 (Wayland) session

    handle_login;

    # We're now in a wayland session, which is in a different VT
    update_x11_vt;
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;

