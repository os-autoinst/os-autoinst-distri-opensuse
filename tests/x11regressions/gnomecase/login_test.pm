# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "x11test";
use strict;
use testapi;
use utils;

#testcase 5255-1503905: Gnome:gnome-login test
#other login scenario has been coverred by the change_password script, here
#only cover the auto_login

sub auto_login_alter {
    send_key "super";
    type_string "settings", 1;    #use 1 to give gnome-shell enough time searching the user-settings module.
    send_key "ret";
    assert_screen "gnome-settings";
    type_string "users";
    assert_screen "settings-users-selected";
    send_key "ret";
    assert_screen "users-settings";
    assert_and_click "Unlock-user-settings";
    assert_screen "authentication-required-user-settings";
    type_string $password;
    assert_and_click "authenticate";
    send_key "alt-u";
    send_key "alt-f4";
}

sub reboot_system {
    wait_idle;
    send_key "ctrl-alt-delete";    #reboot
    assert_screen 'logoutdialog', 15;
    assert_and_click 'logoutdialog-reboot-highlighted';
    if (check_screen("reboot-auth", 5)) {
        type_string $password, 1;
        assert_and_click "authenticate";
    }
    assert_screen "generic-desktop", 200;
}

sub run () {
    my $self = shift;

    assert_screen "generic-desktop";
    auto_login_alter;
    reboot_system;
    auto_login_alter;
}

1;
# vim: set sw=4 et:
