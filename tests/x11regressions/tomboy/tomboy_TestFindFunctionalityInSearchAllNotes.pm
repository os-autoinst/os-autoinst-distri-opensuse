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

# test tomboy: what links here
# testcase 1248883

# this part contains the steps to run this test
sub run() {
    my $self = shift;

    # open tomboy
    x11_start_program("tomboy note");

    # create a note
    send_key "ctrl-n";
    sleep 2;
    type_string "hehe";
    sleep 1;
    send_key "alt-f4";
    wait_idle;

    send_key "alt-f9";
    sleep 2;
    type_string "hehe";
    sleep 1;
    assert_screen 'test-tomboy_TestFindFunctionalityInSearchAllNotes-1', 3;
    sleep 2;
    send_key "alt-f4";
    wait_idle;

    # test Edit->preferences
    send_key "alt-f9";
    sleep 2;
    send_key "alt-e";
    sleep 1;
    send_key "p";
    sleep 1;
    assert_screen 'test-tomboy_TestFindFunctionalityInSearchAllNotes-2', 3;
    sleep 2;
    send_key "alt-f4";
    sleep 1;
    send_key "alt-f4";
    wait_idle;

    # test Help->Contents
    send_key "alt-f9";
    sleep 2;
    send_key "alt-h";
    sleep 1;
    send_key "c";
    sleep 1;
    assert_screen 'test-tomboy_TestFindFunctionalityInSearchAllNotes-3', 3;
    sleep 2;
    send_key "alt-f4";
    sleep 1;
    send_key "alt-f4";
    wait_idle;

    # test Help-> About
    send_key "alt-f9";
    sleep 2;
    send_key "alt-h";
    send_key "a";
    sleep 1;
    assert_screen 'test-tomboy_TestFindFunctionalityInSearchAllNotes-4', 3;
    sleep 2;
    send_key "alt-f4";
    sleep 1;
    send_key "alt-f4";
    wait_idle;

    # test File->Close
    send_key "alt-f";
    sleep 1;
    send_key "c";
    sleep 1;
    assert_screen 'test-tomboy_TestFindFunctionalityInSearchAllNotes-5', 3;
    sleep 2;

    # delete the created note
    send_key "alt-f9";
    sleep 1;
    send_key "up";
    sleep 1;
    send_key "delete";
    sleep 1;
    send_key "alt-d";
    sleep 1;
    send_key "alt-f4";
    wait_idle;
}

1;
# vim: set sw=4 et:
