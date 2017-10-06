# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: tomboy: start note cannot be deleted
# Maintainer: Oliver Kurz <okurz@suse.de>
# Tags: tc#1248873

use base "x11regressiontest";
use strict;
use testapi;

sub run {
    x11_start_program('tomboy note', valid => 0);

    # select "start note", to see that start note cann't be deleted
    send_key "tab";
    send_key "down";
    send_key "down";
    send_key "ret";
    check_screen "tomboy_delete_0";    # to see if the delete buttom is avaiable

    # press the delete button
    send_key "alt-t";
    send_key "esc";
    send_key "right";
    send_key "right";
    send_key "right";
    send_key "ret";
    send_key "ret";
    wait_still_screen;

    send_key "alt-c";
    # FIXME It's really awkward that the start note can be deleted in this test
    # version, so I just cancel the delete process here, and close start note
    # page manually.
    send_key "ctrl-w";
    check_screen "tomboy_delete_1", 5;    # to see if start note still there
    send_key "tab";                       # move the cursor back to text.
    send_key "alt-f4";
}

1;
# vim: set sw=4 et:
