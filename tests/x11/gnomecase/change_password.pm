# SUSE's openQA tests
#
# Copyright © 2016-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Change password in GNOME and check if it's accepted everywhere
#  Testtopia: tc#1503803 tc#1503905; entry for tc#1503973
# Maintainer: chuchingkai <chuchingkai@gmail.com>

use base "x11test";
use strict;
use testapi;
use utils;
use power_action_utils 'reboot_x11';
use version_utils;

#testcase 5255-1503803: Gnome:Change Password

my $newpwd      = "suseTEST-987";
my $newUser     = "test";
my $pwd4newUser = "helloWORLD-0";

sub lock_screen {
    assert_and_click "system-indicator";
    assert_and_click "lock-system";
    send_key "esc";
    assert_screen 'gnome-screenlock-password';
    type_password "$newpwd\n";
    assert_screen "generic-desktop";
}

sub logout_and_login {
    handle_logout;
    assert_screen 'displaymanager';
    mouse_hide();
    wait_still_screen;
    assert_and_click "displaymanager-$username";
    assert_screen 'displaymanager-password-prompt', no_wait => 1;
    type_password "$newpwd\n";
    assert_screen 'generic-desktop', 120;
}

sub reboot_system {
    my ($self) = @_;
    reboot_x11;
    $self->{await_reboot} = 1;
    $self->wait_boot(nologin => 1);
    assert_screen "displaymanager", 200;
    $self->{await_reboot} = 0;
    # The keyboard focus is different between SLE15 and SLE12
    send_key 'up' if sle_version_at_least('15');
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
    send_key 'tab';
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
    send_key 'tab';
    type_string $pwd4newUser;
    assert_screen "actived-add-user";
    send_key "alt-a";
    assert_screen "users-settings", 60;
    send_key "alt-f4";
}

sub run {
    my ($self) = @_;

    #change pwd for current user and add new user for switch scenario
    assert_screen "generic-desktop";
    $self->unlock_user_settings;
    change_pwd;
    add_user;

    #verify changed password work well in the following scenario:
    lock_screen;
    logout_and_login;
    $self->reboot_system;

    #swtich to new added user then switch back
    switch_user;
    send_key "esc";
    assert_and_click 'displaymanager-test';
    assert_screen "testUser-login-dm";
    type_string "$pwd4newUser\n";
    assert_screen "generic-desktop", 120;
    switch_user;
    send_key "esc";
    assert_and_click "displaymanager-$username";
    assert_screen "originUser-login-dm";
    type_string "$newpwd\n";
    assert_screen "generic-desktop", 120;

    #restore password to original value
    x11_start_program('gnome-terminal');
    type_string "su\n";
    assert_screen "pwd4root-terminal";
    type_password "$password\n";
    assert_screen "root-gnome-terminal";
    type_string "passwd $username\n";
    assert_screen "pwd4user-terminal";
    type_password "$password\n";
    assert_screen "pwd4user-confirm-terminal";
    type_password "$password\n";
    assert_screen "password-changed-terminal";

    #delete the added user: test
    # We should kill the active user test in SLE15
    assert_script_run 'loginctl kill-user test' if (sle_version_at_least('15'));
    wait_still_screen;
    type_string "userdel -f test\n";
    assert_screen "user-test-deleted";
    send_key "alt-f4";
    send_key "ret";
}

sub post_fail_hook {
    my ($self) = @_;
    # get rid of plymouth splash during reboot
    send_key 'esc' if $self->{await_reboot};
}

1;
