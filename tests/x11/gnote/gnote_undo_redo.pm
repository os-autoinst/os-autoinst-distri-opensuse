# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Gnote: Test undo and redo
# Maintainer: Xudong Zhang <xdzhang@suse.com>
# Tags: tc#1436173

use base "x11test";
use strict;
use testapi;
use version_utils 'is_sle';


sub undo_redo_once {
    assert_screen 'gnote-new-note-1';
    send_key "ctrl-z";    #undo
    assert_screen 'gnote-new-note';
    send_key "ctrl-shift-z";    #redo
    wait_still_screen 3;
    send_key "left";            #unselect text
    assert_screen 'gnote-new-note-1';
}

sub run {
    my ($self) = @_;
    x11_start_program('gnote');
    send_key "ctrl-n";
    assert_screen 'gnote-new-note';
    type_string "opensuse\nOPENSUSE\n";
    $self->undo_redo_once;

    #assure undo and redo take effect after save note and re-enter note
    send_key "ctrl-tab";    #jump to toolbar
    send_key "ret";         #back to all notes interface
    send_key_until_needlematch 'gnote-new-note-matched', 'down', 6;
    wait_still_screen 3;
    send_key "ret";
    $self->undo_redo_once;

    #clean: remove the created new note
    send_key "esc";
    send_key_until_needlematch 'gnote-new-note-matched', 'down', 6;
    send_key "delete";
    send_key "tab";
    send_key "ret";
    assert_screen "gnote-first-launched";
    send_key "ctrl-w";
}

1;
