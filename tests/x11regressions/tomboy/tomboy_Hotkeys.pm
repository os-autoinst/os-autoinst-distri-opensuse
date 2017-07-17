# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: test tomboy: Hotkeys
# Maintainer: Oliver Kurz <okurz@suse.de>
# Tags: tc#1248875

use base "x11regressiontest";
use strict;
use testapi;


sub run {
    my ($self) = @_;
    # open Hotkeys sheet
    x11_start_program("tomboy note");
    wait_screen_change { send_key 'alt-e' };
    send_key "p";
    sleep 1;
    send_key "right";
    sleep 1;

    # set Hotkeys
    for (1 .. 4) {
        type_string "\t";
    }
    type_string "<Alt>F10\t<Alt>F9";
    assert_screen 'test-tomboy_Hotkeys-1', 3;
    sleep 2;
    wait_screen_change { send_key 'esc' };

    $self->tomboy_logout_and_login;

    # test hotkeys
    send_key "alt-f12";
    sleep 1;
    wait_idle;
    assert_screen 'test-tomboy_Hotkeys-2', 3;
    sleep 1;
    send_key "esc";
    sleep 2;

    send_key "alt-f11";
    sleep 1;
    send_key "up";
    sleep 1;
    wait_idle;
    assert_screen 'test-tomboy_Hotkeys-3', 3;
    sleep 1;
    send_key "ctrl-w";
    sleep 2;

    send_key "alt-f10";
    sleep 10;
    wait_idle;
    assert_screen 'test-tomboy_Hotkeys-4', 3;
    sleep 1;
    send_key "alt-t";
    sleep 3;
    send_key "esc";
    sleep 1;
    send_key "right";
    sleep 1;
    send_key "right";
    sleep 1;
    send_key "right";
    sleep 1;
    send_key "ret";
    sleep 3;
    send_key "alt-d";
    sleep 2;

    send_key "alt-f9";
    sleep 2;
    type_string "sssss\n";
    sleep 1;
    assert_screen 'test-tomboy_Hotkeys-5', 3;
    sleep 1;
    send_key "ctrl-a";
    sleep 1;
    send_key "delete";
    sleep 1;

    # to check all hotkeys
    send_key "alt-e";
    sleep 1;
    send_key "p";
    sleep 1;
    send_key "right";
    sleep 1;
    assert_screen 'test-tomboy_Hotkeys-6', 3;
    sleep 1;
    send_key "esc";
    sleep 2;
    send_key "alt-f4";
}

1;
# vim: set sw=4 et:
