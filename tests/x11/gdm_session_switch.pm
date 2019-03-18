# SUSE's openQA tests
#
# Copyright © 2016-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Add a case for gdm session switch
#    openSUSE has shipped SLE-Classic since Leap 42.2, this case will test
#    gdm session switch among sle-classic, gnome-classic, icewm and gnome.
# Maintainer: Chingkai Chu <chuchingkai@gmail.com>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;

# Smoke test: launch some applications
sub application_test {
    x11_start_program('gnome-terminal');
    send_key "alt-f4";

    x11_start_program('nautilus');
    send_key "alt-f4";
}

sub run {
    my ($self) = @_;

    $self->prepare_sle_classic;
    $self->application_test;

    # Log out and switch to icewm
    $self->switch_wm;
    assert_and_click "displaymanager-settings";
    assert_and_click "dm-icewm";
    send_key "ret";
    assert_screen "desktop-icewm", 120;
    # Smoke test: launch some applications
    send_key "super-spc";
    wait_still_screen;
    type_string "gnome-terminal\n";
    assert_screen "gnome-terminal";
    send_key "alt-f4";
    send_key "super-spc";
    wait_still_screen;
    type_string "nautilus\n";
    assert_screen "test-nautilus-1";
    send_key "alt-f4";
    wait_still_screen;

    # Log out and switch back to GNOME(default)
    send_key "ctrl-alt-delete";
    assert_screen "icewm-session-dialog";
    send_key "alt-l";
    wait_still_screen;
    send_key "alt-o";
    assert_screen "displaymanager";
    send_key "ret";
    assert_screen "originUser-login-dm";
    type_password;
    assert_and_click "displaymanager-settings";
    assert_and_click "dm-gnome";
    send_key "ret";
    assert_screen "generic-desktop", 120;
}

1;
