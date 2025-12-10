# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: gnome-console
# Summary: Basic functionality of gnome console
# - Launch "gnome-console" and confirm it is running
# - Open a second tab
# - Type "If you can see this text gnome-console is working."
# - Close gnome-console
# Maintainer: Santiago Zarate <santiago.zarate@suse.com>

use base "x11test";
use testapi;

sub run {
    my ($self) = @_;
    select_console 'x11';
    mouse_hide(1);
    x11_start_program('kgx');
    send_key "ctrl-shift-t";
    assert_screen "gnome-console-second-tab";
    $self->enter_test_text('gnome-console', cmd => 1);
    assert_screen 'test-gnome_console-1';
    send_key 'alt-f4';
}

1;
