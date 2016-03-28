# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "x11test";
use testapi;
use utils;

#testcase 5255-1503849: Gnome: switch between gnome(now default is sle-classic) and gnome-classic

# logout and switch window-manager
sub switch_wm {
    mouse_set(1000, 30);
    assert_and_click "system-indicator";
    assert_and_click "user-logout-sector";
    assert_and_click "logout-system";
    assert_screen "logout-dialogue";
    send_key "ret";
    assert_screen "displaymanager";
    send_key "ret";
    assert_screen "originUser-login-dm";
    type_string "$password";
}

# try some application could be launched successfully
sub application_test {
    x11_start_program "gnome-terminal";
    assert_screen "gnome-terminal-launched";
    send_key "alt-f4";
    send_key "ret";
    wait_still_screen;

    x11_start_program "firefox";
    assert_screen "firefox-gnome", 150;
    send_key "alt-f4";
    send_key "ret";
    wait_still_screen;
}

sub run () {
    my $self = shift;

    # swith to gnome-classic and try some applications
    assert_screen "generic-desktop";
    switch_wm;
    assert_and_click "displaymanager-settings";
    assert_and_click "dm-gnome-classic";
    send_key "ret";
    assert_screen "desktop-gnome-classic", 120;
    application_test;

    # swith back to default -'sle-classic' and try some applications
    switch_wm;
    assert_and_click "displaymanager-settings";
    assert_and_click "dm-sle-classic";
    send_key "ret";
    assert_screen "generic-desktop", 120;
    application_test;
}

1;
# vim: set sw=4 et:
