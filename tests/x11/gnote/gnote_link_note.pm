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

use base 'x11test';
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_sle is_tumbleweed);


sub run {
    my ($self) = @_;
    $self->gnote_start_with_new_note;
    type_string "Start Here\n";
    assert_screen 'gnote-new-note-link';
    wait_screen_change { send_key 'up' };
    send_key 'ctrl-ret';    #switch to link
    assert_screen 'gnote-note-start-here';

    # click the menu button on the tool bar
    assert_and_click 'gnote-new-note-menu';
    assert_and_click 'gnote-new-note-menu-what-link-here';
    assert_screen 'gnote-what-link-here';
    wait_screen_change { send_key 'esc' };
    #close the note "Start Here"
    wait_screen_change { send_key 'ctrl-w' } if is_sle('<15');
    $self->cleanup_gnote('gnote-new-note-matched');
}

1;
