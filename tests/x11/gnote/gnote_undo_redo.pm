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
use warnings;
use testapi;
use version_utils 'is_sle';


sub undo_redo_once {
    send_key_until_needlematch 'gnote-new-note-1', 'left';
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
    assert_and_click 'gnote-back2allnotes';
    send_key_until_needlematch 'gnote-new-note-matched', 'down', 6;
    wait_still_screen 3;
    send_key "ret";
    $self->undo_redo_once;

    #clean: remove the created new note
    $self->cleanup_gnote('gnote-new-note-matched');
}

1;
