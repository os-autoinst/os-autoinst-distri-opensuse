# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "x11test";
use strict;
use testapi;

# Case 1436121 - Gedit: save file
sub run() {
    my $self = shift;
    # download test text file from x11regression data directory
    x11_start_program("wget " . autoinst_url . "/data/x11regressions/test.txt");

    # open test text file locally
    x11_start_program("gedit " . "test.txt");
    assert_screen 'gedit-file-opened';

    # delete one line
    send_key "ctrl-d";
    send_key "ret";

    # copy one line and past it
    mouse_set(500, 350);
    mouse_tclick('left', 0.10);    # triple click to select a line
    sleep 1;

    send_key "ctrl-c";             # copy
    send_key "right";
    send_key "ret";
    send_key "ctrl-v";             # paste in next line

    # edit some words
    send_key "ctrl-end";           # go to the end of document
    send_key "ret";
    type_string "This file is opened, edited and saved by openQA!";
    sleep 1;

    # save and quit
    wait_screen_change { send_key "ctrl-s"; };
    send_key "ctrl-q";

    # open saved file to validate
    x11_start_program("gedit " . "test.txt");
    assert_screen 'gedit-saved-file', 3;
    wait_screen_change { send_key "ctrl-q"; };

    # clean up saved file
    x11_start_program("rm " . "test.txt");
}

1;
# vim: set sw=4 et:
