# X11 regression tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: systemd
# Summary: Show information about current session (window system)
# - Check current session type
# - Select graphic console (x11), unless DESKTOP is set to textmode
# Maintainer: Jan Baier <jbaier@suse.cz>

use base "x11test";
use testapi;
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;
    my $session_type = get_session_type();
    if ($session_type) {
        record_info("$session_type", "Current session type is $session_type");
    } else {
        die('Session type is not defined');
    }

    select_console 'x11' unless check_var('DESKTOP', 'textmode');
}

1;
