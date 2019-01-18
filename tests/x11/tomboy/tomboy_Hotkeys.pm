# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: test tomboy: Hotkeys
# Maintainer: Oliver Kurz <okurz@suse.de>
# Tags: tc#1248875

use base "x11test";
use strict;
use warnings;
use testapi;


sub run {
    my ($self) = @_;
    # open Hotkeys sheet
    x11_start_program('tomboy note', valid => 0);
    wait_screen_change { send_key 'alt-e' };
    send_key "p";
    send_key "right";

    # set Hotkeys
    for (1 .. 4) {
        type_string "\t";
    }
    type_string "<Alt>F10\t<Alt>F9";
    assert_screen 'test-tomboy_Hotkeys-1', 3;
    wait_screen_change { send_key 'esc' };

    $self->tomboy_logout_and_login;

    # test hotkeys
    send_key "alt-f12";
    assert_screen 'test-tomboy_Hotkeys-2';
    send_key "esc";

    send_key "alt-f11";
    send_key "up";
    assert_screen 'test-tomboy_Hotkeys-3';
    send_key "ctrl-w";

    send_key "alt-f10";
    assert_screen 'test-tomboy_Hotkeys-4';
    send_key "alt-t";
    send_key "esc";
    send_key "right";
    send_key "right";
    send_key "right";
    send_key "ret";
    send_key "alt-d";

    send_key "alt-f9";
    type_string "sssss\n";
    assert_screen 'test-tomboy_Hotkeys-5', 3;
    send_key "ctrl-a";
    send_key "delete";

    # to check all hotkeys
    send_key "alt-e";
    send_key "p";
    send_key "right";
    assert_screen 'test-tomboy_Hotkeys-6', 3;
    send_key "esc";
    send_key "alt-f4";
}

1;
