# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test link in note
# Maintainer: Xudong Zhang <xdzhang@suse.com>
# Tags: tc#1436158

use base 'x11regressiontest';
use strict;
use testapi;


sub run() {
    my ($self) = @_;
    $self->gnote_start_with_new_note;
    type_string "Start Here\n";
    assert_screen 'gnote-new-note-link';
    wait_screen_change { send_key 'up' };
    send_key 'ctrl-ret';    #switch to link
    assert_screen 'gnote-note-start-here';

    wait_screen_change { send_key 'ctrl-tab' };    #jump to toolbar
    wait_screen_change {
        for (1 .. 6) { send_key 'right' }
    };
    wait_screen_change { send_key 'ret' };
    wait_screen_change { send_key 'down' };
    if (get_var('SP2ORLATER')) {
        wait_screen_change { send_key 'ret' };
    }
    assert_screen 'gnote-what-link-here';
    wait_screen_change { send_key 'esc' };
    #close the note "Start Here"
    wait_screen_change { send_key 'ctrl-w' };
    $self->cleanup_gnote;
}

1;
# vim: set sw=4 et:
