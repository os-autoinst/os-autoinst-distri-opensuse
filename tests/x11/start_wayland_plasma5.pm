# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Prepare for wayland and log out of X11 and into wayland
# Maintainer: Fabian Vogt <fvogt@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = @_;

    # Make sure everything necessary is installed
    ensure_installed "plasma5-session-wayland";

    # Log out of X session
    send_key 'super';    # Open the application menu

    # Logout in kicker and kickoff is different
    assert_screen(["desktop_mainmenu-kicker", "desktop_mainmenu-kickoff"]);
    if (match_has_tag('desktop_mainmenu-kicker')) {
        assert_and_click 'plasma_logout_btn';    # Click on the logout button
    }
    elsif (match_has_tag('desktop_mainmenu-kickoff')) {
        assert_and_click 'plasma_kickoff_leave';     # Switch to the leave section
        assert_and_click 'plasma_kickoff_logout';    # Click on the logout button
    }

    assert_and_click 'plasma_overlay_confirm';       # Confirm logout

    # Now we're in sddm
    assert_and_click 'sddm_desktopsession';            # Open session selection box
    assert_and_click 'sddm_session_plasma_wayland';    # Select Plasma 5 (Wayland) session

    # Log in as usual
    type_password;
    send_key 'ret';

    # Wait until logged in
    assert_screen 'generic-desktop', 60;

    # We're now in a wayland session, which is in a different VT
    x11_start_program('xterm');
    my $tty = script_output('echo $XDG_VTNR');
    send_key("alt-f4");                                # close xterm

    console('x11')->set_tty(int($tty));
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;

