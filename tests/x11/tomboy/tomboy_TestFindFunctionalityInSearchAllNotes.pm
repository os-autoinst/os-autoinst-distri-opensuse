# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: test tomboy: what links here
# Maintainer: Sero Sun <yosun@suse.com>
# Tags: tc#1248883

use base "x11test";
use strict;
use warnings;
use testapi;


sub run {
    # open tomboy
    x11_start_program('tomboy note', valid => 0);

    # create a note
    wait_screen_change { send_key "ctrl-n" };
    type_string "hehe";
    save_screenshot;
    wait_screen_change { send_key 'alt-f4' };

    wait_screen_change { send_key "alt-f9" };
    type_string "hehe";
    assert_screen 'test-tomboy_TestFindFunctionalityInSearchAllNotes-1';
    wait_screen_change { send_key 'alt-f4' };

    # test Edit->preferences
    send_key "alt-f9";
    send_key "alt-e";
    send_key "p";
    assert_screen 'test-tomboy_TestFindFunctionalityInSearchAllNotes-2';
    send_key "alt-f4";
    wait_screen_change { send_key 'alt-f4' };

    # test Help->Contents
    send_key "alt-f9";
    send_key "alt-h";
    send_key "c";
    assert_screen 'test-tomboy_TestFindFunctionalityInSearchAllNotes-3';
    send_key "alt-f4";
    wait_screen_change { send_key 'alt-f4' };

    # test Help-> About
    send_key "alt-f9";
    send_key "alt-h";
    send_key "a";
    assert_screen 'test-tomboy_TestFindFunctionalityInSearchAllNotes-4';
    send_key "alt-f4";
    wait_screen_change { send_key 'alt-f4' };

    # test File->Close
    send_key "alt-f";
    send_key "c";
    assert_screen 'test-tomboy_TestFindFunctionalityInSearchAllNotes-5';

    # delete the created note
    send_key "alt-f9";
    send_key "up";
    send_key "delete";
    send_key "alt-d";
    wait_screen_change { send_key 'alt-f4' };
}

1;
