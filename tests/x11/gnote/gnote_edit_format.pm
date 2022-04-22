# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: gnote
# Summary: test gnote note format
# - Launch gnome, create a new note and check
# - Type "opensuse" and CTRL-H to turn highlight on
# - Type "opensuse" and CTRL-B to turn bold on
# - Type "opensuse" and CTRL-B to turn bold off
# - Press CTRL-B to turn highlight off
# - Press CTRL-I to turn italic on
# - Type "opensuse" and CTRL-S to turn strikeline on
# - Type "opensuse" and CTRL-S to turn strikeline off
# - Press CTRL-I to turn italic off and check results
# - Close gnote and cleanup
# Maintainer: Xudong Zhang <xdzhang@suse.com>
# Tags: tc#1436163

use base "x11test";
use strict;
use warnings;
use testapi;
use version_utils qw(is_sle is_tumbleweed);


sub run {
    my ($self) = @_;
    $self->gnote_start_with_new_note;
    enter_cmd "opensuse";
    send_key "ctrl-h";    #hightlight on
    enter_cmd "opensuse";
    send_key "ctrl-b";    #bold on
    enter_cmd "opensuse";
    send_key "ctrl-b";    #bold off
    send_key "ctrl-h";    #hightlight off
    send_key "ctrl-i";    #italic on
    enter_cmd "opensuse";
    send_key "ctrl-s";    #strikeline on
    enter_cmd "opensuse";
    send_key "ctrl-s";    #strikeline off
    send_key "ctrl-i";    #italic off
    assert_screen 'gnote-edit-format', 5;
    assert_and_click 'close-new-note1' if (is_tumbleweed || is_sle('>=15-SP4'));

    $self->cleanup_gnote('gnote-new-note-matched');
}

1;
