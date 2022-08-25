# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: gnote
# Summary: Gnote: Test undo and redo
# - Launch gnote
# - Send CTRL-N, create a new note and check
# - Type "opensuse"<ENTER>
# - Type "OPENSUSE"<ENTER>
# - Send CTRL-Z and check
# - Send CTRL-SHIFT-Z and check
# - Click button to back to all notes
# - Select new note
# - Send CTRL-Z and check
# - Send CTRL-SHIFT-Z and check
# - Cleanup gnote
# Maintainer: Xudong Zhang <xdzhang@suse.com>
# Tags: tc#1436173

use base "x11test";
use strict;
use warnings;
use testapi;
use version_utils qw(is_sle is_tumbleweed);


sub undo_redo_once {
    send_key_until_needlematch 'gnote-new-note-1', 'left';
    send_key "ctrl-z";    #undo
    assert_screen 'gnote-new-note';
    send_key "ctrl-shift-z";    #redo
    wait_still_screen 3;
    send_key "left";    #unselect text
    assert_screen 'gnote-new-note-1';
}

sub run {
    my ($self) = @_;
    x11_start_program('gnote');
    send_key "ctrl-n";
    assert_screen 'gnote-new-note';
    enter_cmd "opensuse\nOPENSUSE";
    $self->undo_redo_once;

    #assure undo and redo take effect after save note and re-enter note
    assert_and_click 'gnote-back2allnotes';
    assert_and_dclick 'gnote-new-note-matched';
    $self->undo_redo_once;
    assert_and_click 'close-new-note1' if (is_tumbleweed || is_sle('>=15-SP4'));

    #clean: remove the created new note
    $self->cleanup_gnote('gnote-new-note-matched');
}

1;
