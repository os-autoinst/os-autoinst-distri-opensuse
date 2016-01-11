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

# case 1436173-test undo and redo

sub run() {
    my $self = shift;

    x11_start_program("gnote");
    assert_screen "gnote-first-launched", 10;
    send_key "ctrl-n";
    assert_screen 'gnote-new-note', 5;
    type_string "opensuse\nOPENSUSE\n";
    assert_screen 'gnote-new-note-1', 5;
    send_key "ctrl-z";    #undo
    assert_screen 'gnote-new-note', 5;
    send_key "ctrl-shift-z";    #redo
    sleep 2;
    send_key "left";            #unselect text
    assert_screen 'gnote-new-note-1', 5;

    #assure undo and redo take effect after save note and re-enter note
    send_key "ctrl-tab";        #jump to toolbar
    sleep 2;
    send_key "ret";             #back to all notes interface
    send_key_until_needlematch 'gnote-new-note-matched', 'down', 6;
    send_key "ret";
    assert_screen 'gnote-new-note-1', 5;
    send_key "ctrl-z";          #undo
    assert_screen 'gnote-new-note', 5;
    send_key "ctrl-shift-z";    #redo
    sleep 2;
    send_key "left";            #unselect text
    assert_screen 'gnote-new-note-1', 5;

    #clean: remove the created new note
    send_key "ctrl-tab";        #jump to toolbar
    sleep 2;
    send_key "ret";             #back to all notes interface
    send_key_until_needlematch 'gnote-new-note-matched', 'down', 6;
    send_key "delete";
    sleep 2;
    send_key "tab";
    sleep 2;
    send_key "ret";
    assert_screen "gnote-first-launched", 5;
    send_key "ctrl-w";
}

1;
# vim: set sw=4 et:
