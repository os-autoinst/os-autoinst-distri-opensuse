# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: Add a case for gdm session switch
#    openSUSE has shipped SLE-Classic since Leap 42.2, this case will test
#    gdm session switch among sle-classic, gnome-classic, icewm and gnome.
# G-Maintainer: Chingkai Chu <chuchingkai@gmail.com>

use base "x11test";
use strict;
use testapi;
use utils;

# Smoke test: launch some applications
sub application_test {
    x11_start_program "gnome-terminal";
    assert_screen "gnome-terminal";
    send_key "alt-f4";

    x11_start_program "nautilus";
    assert_screen "test-nautilus-1";
    send_key "alt-f4";
}

sub run () {
    # Log out and switch to GNOME Classic
    assert_screen "generic-desktop";
    switch_wm;
    assert_and_click "displaymanager-settings";
    assert_and_click "dm-gnome-classic";
    send_key "ret";
    assert_screen "desktop-gnome-classic", 120;
    application_test;

    # Log out and switch to SLE Classic
    switch_wm;
    assert_and_click "displaymanager-settings";
    assert_and_click "dm-sle-classic";
    send_key "ret";
    assert_screen "desktop-sle-classic", 120;
    application_test;

    # Log out and switch to icewm
    switch_wm;
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
    type_string "$password";
    assert_and_click "displaymanager-settings";
    assert_and_click "dm-gnome";
    send_key "ret";
    assert_screen "generic-desktop", 120;
}

1;
# vim: set sw=4 et:
