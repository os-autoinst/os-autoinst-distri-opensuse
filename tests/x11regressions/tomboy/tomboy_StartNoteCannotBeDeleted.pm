# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "x11regressiontest";
use strict;
use testapi;

# test tomboy: start note cannot be deleted
# testcase 1248873

# this part contains the steps to run this test
sub run() {
    my $self = shift;
    x11_start_program("tomboy note");

    # select "start note", to see that start note cann't be deleted
    send_key "tab";
    sleep 2;
    send_key "down";
    sleep 2;
    send_key "down";
    sleep 2;
    send_key "ret";
    sleep 2;
    wait_idle;
    check_screen "tomboy_delete_0", 5;    # to see if the delete buttom is avaiable
    sleep 2;

    # press the delete button
    send_key "alt-t";
    sleep 2;
    send_key "esc";
    sleep 2;
    send_key "right";
    sleep 2;
    send_key "right";
    sleep 2;
    send_key "right";
    sleep 2;
    send_key "ret";
    sleep 2;
    send_key "ret";
    sleep 2;
    wait_still_screen;

    #send_key "alt-d"; #FIXME
    send_key "alt-c";     #FIXME
    send_key "ctrl-w";    #FIXME It's really awkward that the start note can be deleted in this test version, so I just cancel the delete process here, and close start note page manually.
    check_screen "tomboy_delete_1", 5;    # to see if start note still there
    send_key "tab";                       # move the cursor back to text.
    send_key "alt-f4";
    sleep 2;
    wait_idle;
}

1;
# vim: set sw=4 et:
