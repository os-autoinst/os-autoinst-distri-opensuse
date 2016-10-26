# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Change password in GNOME and check if it's accepted everywhere
#  Testtopia: tc#1503803 tc#1503905; entry for tc#1503973
# Maintainer: chuchingkai <chuchingkai@gmail.com>

use base "x11regressiontest";
use strict;
use testapi;
use utils;

#testcase 5255-1503803: Gnome:Change Password

my $newpwd      = "suseTEST-987";
my $newUser     = "test";
my $pwd4newUser = "helloWORLD-0";

sub lock_screen {
    assert_and_click "system-indicator";
    assert_and_click "lock-system";
    send_key "esc";
    assert_screen 'gnome-screenlock-password';
    type_string "$newpwd\n";
    assert_screen "generic-desktop";
}

sub logout_and_login {
    assert_and_click "system-indicator";
    assert_and_click "user-logout-sector";
    assert_and_click "logout-system";
    send_key "ret";
    assert_screen "displaymanager";
    send_key "ret";
    type_string "$newpwd\n";
    assert_screen "generic-desktop";
}

sub reboot_system {
    wait_idle;
    send_key "ctrl-alt-delete";    #reboot
    assert_screen 'logoutdialog', 15;
    assert_and_click 'logoutdialog-reboot-highlighted';
    if (check_screen("reboot-auth", 5)) {
        type_string $password;
        assert_and_click "authenticate";
    }
    assert_screen "displaymanager", 200;
    send_key "ret";
    wait_still_screen;
    type_string "$newpwd\n";
    assert_screen "generic-desktop";
}

sub switch_user {
    assert_and_click "system-indicator";
    assert_and_click "user-logout-sector";
    assert_and_click "switch-user";
}

sub change_pwd {
    send_key "alt-p";
    wait_still_screen;
    send_key "ret";
    wait_still_screen;
    send_key "alt-p";
    wait_still_screen;
    type_password;
    wait_still_screen;
    send_key "alt-n";
    wait_still_screen;
    type_string $newpwd;
    wait_still_screen;
    send_key "alt-v";
    wait_still_screen;
    type_string $newpwd;
    assert_screen "actived-change-password";
    send_key "alt-a";
    assert_screen "users-settings", 60;
}

sub add_user {
    assert_and_click "add-user";
    type_string $newUser;
    assert_screen("input-username-test");
    assert_and_click "set-password-option";
    send_key "alt-p";
    type_string $pwd4newUser;
    send_key "alt-v";
    type_string $pwd4newUser;
    assert_screen "actived-add-user";
    send_key "alt-a";
    assert_screen "users-settings", 60;
    send_key "alt-f4";
}

sub run () {
    my ($self) = @_;

    #change pwd for current user and add new user for switch scenario
    assert_screen "generic-desktop";
    $self->unlock_user_settings;
    change_pwd;
    add_user;

    #verify changed password work well in the following scenario:
    lock_screen;
    logout_and_login;
    reboot_system;
    #swtich to new added user then switch back
    switch_user;
    send_key "esc";
    assert_screen "displaymanager";
    send_key "down";
    send_key "ret";
    assert_screen "testUser-login-dm";
    type_string "$pwd4newUser\n";
    assert_screen "generic-desktop", 60;
    switch_user;
    send_key "esc";
    assert_screen "displaymanager";
    send_key "ret";
    assert_screen "originUser-login-dm";
    type_string "$newpwd\n";
    assert_screen "generic-desktop", 60;

    #restore password to original value
    x11_start_program("gnome-terminal");
    type_string "su\n";
    assert_screen "pwd4root-terminal";
    type_string "$password\n";
    assert_screen "root-gnome-terminal";
    type_string "passwd $username\n";
    assert_screen "pwd4user-terminal";
    type_string "$password\n";
    assert_screen "pwd4user-confirm-terminal";
    type_string "$password\n";
    assert_screen "password-changed-terminal";

    #delete the added user: test
    type_string "userdel -f test\n";
    assert_screen "user-test-deleted";
    send_key "alt-f4";
    send_key "ret";
}

1;
# vim: set sw=4 et:
