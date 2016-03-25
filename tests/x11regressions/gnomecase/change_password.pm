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

#testcase 5255-1503803: Gnome:Change Password

my $rootpwd = "$password";
my $password;
my $newpwd      = "suseTEST-987";
my $newUser     = "test";
my $pwd4newUser = "helloWORLD-0";

sub lock_screen {
    assert_and_click "system-indicator";
    assert_and_click "lock-system";
    type_string "$password";
    send_key "ret";
    assert_screen "generic-desktop";
}

sub logout_and_login {
    assert_and_click "system-indicator";
    assert_and_click "user-logout-sector";
    assert_and_click "logout-system";
    send_key "ret";
    assert_screen "displaymanager";
    send_key "ret";
    type_string "$password";
    send_key "ret";
    assert_screen "generic-desktop";
}

sub reboot_system {
    wait_idle;
    send_key "ctrl-alt-delete";    #reboot
    assert_screen 'logoutdialog', 15;
    assert_and_click 'logoutdialog-reboot-highlighted';
    if (check_screen("reboot-auth", 5)) {
        type_string "$rootpwd";
        assert_and_click "authenticate";
    }
    assert_screen "displaymanager", 200;
    send_key "ret";
    wait_still_screen;
    type_string "$password";
    send_key "ret";
    assert_screen "generic-desktop";
}

sub switch_user {
    assert_and_click "system-indicator";
    assert_and_click "user-logout-sector";
    assert_and_click "switch-user";
}

sub unlock_user_settings {
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
    type_string "$rootpwd";
    assert_and_click "authenticate";
}

sub change_pwd {
    send_key "alt-p";
    send_key "ret";
    send_key "alt-p";
    type_string "$rootpwd";
    send_key "alt-n";
    type_string "$newpwd";
    send_key "alt-v";
    type_string "$newpwd";
    assert_screen "actived-change-password";
    send_key "alt-a";
    assert_screen "users-settings", 60;
    $password = $newpwd;
}

sub add_user {
    assert_and_click "add-user";
    type_string "$newUser";
    unless (assert_screen("input-username-test")) {
        send_key "alt-f";
        type_string "$newUser";
    }
    assert_and_click "set-password-option";
    send_key "alt-p";
    type_string "$pwd4newUser";
    send_key "alt-v";
    type_string "$pwd4newUser";
    assert_screen "actived-add-user";
    send_key "alt-a";
    assert_screen "users-settings", 60;
    send_key "alt-f4";
}

sub run () {
    my $self = shift;

    #change pwd for current user and add new user for switch scenario
    assert_screen "generic-desktop";
    unlock_user_settings;
    change_pwd;
    add_user;

    #verify changed password work well in the following scenario:
    lock_screen;
    logout_and_login;
    reboot_system;
    #swtich to new added user then switch back
    switch_user;
    assert_screen "displaymanager";
    send_key "down";
    send_key "ret";
    assert_screen "testUser-login-dm";
    type_string "$pwd4newUser";
    send_key "ret";
    assert_screen "generic-desktop", 60;
    switch_user;
    assert_screen "displaymanager";
    send_key "ret";
    assert_screen "originUser-login-dm";
    type_string "$password";
    send_key "ret";
    assert_screen "generic-desktop", 60;

    #restore password to original value
    x11_start_program("gnome-terminal");
    type_string "su";
    send_key "ret";
    assert_screen "pwd4root-terminal";
    type_string "$rootpwd";
    send_key "ret";
    assert_screen "root-gnome-terminal";
    type_string "passwd $username";
    send_key "ret";
    assert_screen "pwd4user-terminal";
    type_string "$rootpwd";
    send_key "ret";
    assert_screen "pwd4user-confirm-terminal";
    type_string "$rootpwd";
    send_key "ret";
    assert_screen "password-changed-terminal";

    #delete the added user: test
    type_string "userdel -f test";
    send_key "ret";
    assert_screen "user-test-deleted";
    send_key "alt-f4";
    send_key "ret";
}

1;
# vim: set sw=4 et:
