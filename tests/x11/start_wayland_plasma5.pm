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
use testapi;
use utils;

sub run {
    my ($self) = @_;

    # Make sure everything necessary is installed
    ensure_installed "plasma5-session-wayland";

    # Workaround (part 1): use softpipe as llvmpipe crashes all the time (fdo#96953)
    x11_start_program('mkdir -p ~/.config/plasma-workspace/env',                                                                            valid => 0);
    x11_start_program("echo 'echo export GALLIUM_DRIVER=softpipe >> ~/.config/startupconfig' > ~/.config/plasma-workspace/env/softpipe.sh", valid => 0);

    # Log out of X session
    send_key 'super';                             # Open the application menu
    assert_and_click 'plasma_logout_btn';         # Click on the logout button
    assert_and_click 'plasma_overlay_confirm';    # Confirm logout

    # Now we're in sddm
    assert_and_click 'sddm_desktopsession';            # Open session selection box
    assert_and_click 'sddm_session_plasma_wayland';    # Select Plasma 5 (Wayland) session

    # Log in as usual
    type_password;
    send_key 'ret';

    # Wait until logged in
    assert_screen 'generic-desktop', 60;

    # We're now in a wayland session, which is in a different VT
    console('x11')->{args}->{tty} = 3;

    # Workaround (part 2): KWin does not work with the workaround so we need to undo it
    # to allow relogins to succeed
    x11_start_program('rm ~/.config/startupconfig', valid => 0);
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;

