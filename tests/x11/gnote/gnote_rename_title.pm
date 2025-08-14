# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: gnote
# Summary: Rename gnote title
# - Launch gnote
# - Send CTRL-N and check
# - Send UP twice, type "new title-opensuse"  and check
# Maintainer: Xudong Zhang <xdzhang@suse.com>
# Tags: tc#1436169

use base "x11test";
use testapi;
use version_utils qw(is_sle is_tumbleweed);


sub run {
    my ($self) = @_;
    $self->gnote_start_with_new_note;
    send_key "up";
    send_key "up";
    enter_cmd "new title-opensuse";
    assert_and_click 'close-new-note-title' if (is_tumbleweed || is_sle('>=15-SP4'));
    $self->cleanup_gnote('gnote-new-note-title-matched');
}

1;
