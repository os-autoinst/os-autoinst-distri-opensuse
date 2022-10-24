# X11 regression tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: systemd
# Summary: Show information about current session (window system)
# - Check current session type
# - Select graphic console (x11), unless DESKTOP is set to textmode
# Maintainer: Jan Baier <jbaier@suse.cz>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;

    my $session_type = script_output(
        "loginctl show-session \$(loginctl list-sessions | awk '/$testapi::username/ {print \$1};') -p Type | cut -f2 -d=",
        undef, type_command => 1,
    );

    if ($session_type) {
        record_info("$session_type", "Current session type is $session_type");
    } else {
        die('Session type is not defined');
    }

    select_console 'x11' unless check_var('DESKTOP', 'textmode');
}

1;
