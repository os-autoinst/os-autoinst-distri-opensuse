# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: gnome-terminal
# Summary: Basic functionality of gnome terminal
# - Launch "gnome-terminal" and confirm it is running
# - Open a second tab
# - Type "If you can see this text gnome-terminal is working."
# - Close gnome-terminal
# Maintainer: QE Core <qe-core@suse.de>

use base "x11test";
use testapi;
use version_utils qw(is_sle is_leap);

sub run {
    my ($self) = @_;
    mouse_hide(1);
    ensure_installed('gnome-terminal') unless (is_leap("<16") || is_sle("<16"));
    x11_start_program('gnome-terminal');
    send_key "ctrl-shift-t";
    if (!check_screen "gnome-terminal-second-tab", 30) {
        record_info('workaround', 'gnome_terminal does not open second terminal when shortcut is pressed (see bsc#999243)');
    }
    $self->enter_test_text('gnome-terminal', cmd => 1);
    assert_screen 'test-gnome_terminal-1';
    send_key 'alt-f4';
}

1;
