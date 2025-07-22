# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: mate-terminal
# Summary: Check basic functionality of mate terminal
# Maintainer: Dominique Leuenberger <dimstar@opensuse.org>

use base "x11test";
use testapi;

sub run {
    my ($self) = @_;
    mouse_hide(1);
    x11_start_program('mate-terminal');
    send_key "ctrl-shift-t";
    assert_screen "mate-terminal-second-tab";
    $self->enter_test_text('mate-terminal', cmd => 1);
    assert_screen 'test-mate_terminal-1';
    send_key "alt-f4";
    assert_screen([qw(mate-terminal-confirm_close generic-desktop)]);
    send_key 'ret' if match_has_tag 'mate-terminal-confirm_close';
}

1;
