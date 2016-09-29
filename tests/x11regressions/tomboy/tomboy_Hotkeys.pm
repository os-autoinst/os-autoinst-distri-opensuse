# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: add some new script
# G-Maintainer: root <root@linux-t9vu.site>

use base "x11regressiontest";
use strict;
use testapi;

# test tomboy: Hotkeys
# testcase 1248875

# this part contains the steps to run this test
sub run() {
    my $self = shift;

    # open Hotkeys sheet
    x11_start_program("tomboy note");
    send_key "alt-e";
    sleep 1;
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
    send_key "esc";
    wait_idle;
    send_key "alt-f4";

    # logout
    send_key "alt-f2";
    sleep 1;
    type_string "gnome-session-quit --logout --force\n";
    sleep 20;
    wait_idle;

    # login and open tomboy again
    send_key "ret";
    sleep 2;
    wait_still_screen;
    type_password();
    sleep 2;
    send_key "ret";
    sleep 20;
    wait_idle;
    x11_start_program("tomboy note");

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
    sleep 2;
}

1;
# vim: set sw=4 et:
