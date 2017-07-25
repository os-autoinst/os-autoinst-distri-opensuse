# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: test tomboy: open
# Maintainer: Oliver Kurz <okurz@suse.de>
# Tags: tc#1248874

use base "x11regressiontest";
use strict;
use testapi;


sub run {
    my ($self) = @_;
    # open start note and take screenshot
    x11_start_program("tomboy note");
    send_key "alt-f11";
    send_key "ctrl-home";
    type_string "Rename_";
    wait_screen_change { send_key 'ctrl-w' };

    # Check hotkey for open "start here" still works
    send_key "alt-fll";
    wait_still_screen;
    check_screen "tomboy_open_0", 5;

    send_key "shift-up";
    send_key "delete";
    send_key "ctrl-w";
    $self->tomboy_logout_and_login;

    send_key "alt-f11";
    send_key "up";
    check_screen "tomboy_open_1", 5;
    send_key "ctrl-w";
    send_key "alt-f4";
}

1;
# vim: set sw=4 et:
