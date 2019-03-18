# X11 regression tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Show information about current session (window system)
# Maintainer: Jan Baier <jbaier@suse.cz>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    my $session_type = script_output(
        "loginctl show-session \$(loginctl list-sessions | awk '/$testapi::username/ {print \$1};') -p Type | cut -f2 -d=",
        undef, type_command => 1,
    );

    if ($session_type) {
        record_info("$session_type", "Current session type is $session_type");
    } else {
        record_soft_fail("Session type is not defined");
    }

    type_string "exit\n";    # logout

    select_console 'x11' unless check_var('DESKTOP', 'textmode');
}

1;
