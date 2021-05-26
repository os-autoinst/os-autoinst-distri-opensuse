# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Package for users service test
# Test steps:
# Before migration:
#   1.Change current user's password and verify new one works.
#   2.Add new user and set password.
#   3.Restore current user's password to ensure won't be block by later test.
# After migration:
#   4.Switch Bernhard and new user.
# Maintainer: Lemon Li <leli@suse.com>

package services::users;
use base "x11test";
use Exporter;
use strict;
use warnings;
use testapi;
use utils;
use power_action_utils 'reboot_x11';
use version_utils;
use x11utils;
use main_common 'opensuse_welcome_applicable';

our @EXPORT      = qw($newpwd $newUser $pwd4newUser);
our $newpwd      = "suseTEST-987";
our $newUser     = "test";
our $pwd4newUser = "helloWORLD-0";

sub lock_screen {
    assert_and_click "system-indicator";
    assert_and_click "lock-system";
    send_key_until_needlematch 'gnome-screenlock-password', 'esc', 5, 10;
    type_password "$newpwd\n";
    assert_screen "generic-desktop";
}

sub logout_and_login {
    my ($login_user, $login_pw) = @_;
    my $test_user = $login_user // $username;
    my $test_pw   = $login_pw   // $newpwd;
    handle_logout;
    send_key_until_needlematch 'displaymanager', 'esc', 9, 10;
    mouse_hide();
    wait_still_screen;
    assert_and_click "displaymanager-$test_user";
    assert_screen 'displaymanager-password-prompt', no_wait => 1;
    type_password "$test_pw\n";
    assert_screen 'generic-desktop', 120;
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
    wait_still_screen;
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

#swtich to new added user then switch back
sub switch_users {
    switch_user;
    wait_still_screen 5;
    send_key "esc";
    assert_and_click 'displaymanager-test';
    assert_screen "testUser-login-dm";
    type_password "$pwd4newUser\n";
    # Handle welcome screen, when needed
    handle_welcome_screen(timeout => 120) if (opensuse_welcome_applicable);
    assert_screen "generic-desktop", 120;
    switch_user;
    send_key "esc";
    assert_and_click "displaymanager-$username";
    assert_screen "originUser-login-dm";
    #For poo#88247, we have to restore current user's password before migration,
    #so here need to use the original password.
    type_password(get_required_var('FLAVOR') =~ /Migration/ ? "$password\n" : "$newpwd\n");
    assert_screen "generic-desktop", 120;
}

#restore password to original value
sub restore_passwd {
    x11_start_program('gnome-terminal');
    enter_cmd "su";
    assert_screen "pwd4root-terminal";
    type_password "$password\n";
    assert_screen "root-gnome-terminal";
    enter_cmd "passwd $username";
    assert_screen "pwd4user-terminal";
    type_password "$password\n";
    assert_screen "pwd4user-confirm-terminal";
    type_password "$password\n";
    assert_screen "password-changed-terminal";
}

# check users before and after migration
# stage is 'before' or 'after' system migration.
sub full_users_check {
    my (%hash) = @_;
    my $stage = $hash{stage};

    # Since the users test is only supported on gnome, will quit the test if not on gnome.
    my $desktop = get_var('DESKTOP');
    if (!check_var("DESKTOP", "gnome")) {
        record_info('Unsupported on non-gnome', "This test is only supported on gnome, quit for your DESKTOP is $desktop", result => 'fail');
        return;
    }
    # reset consoles before select x11 console will make the connect operation
    # more stable on s390x
    reset_consoles             if check_var('ARCH',    's390x');
    turn_off_gnome_screensaver if check_var('DESKTOP', 'gnome');
    select_console 'x11', await_console => 0;
    wait_still_screen 5;
    ensure_unlocked_desktop;
    assert_screen "generic-desktop";
    if ($stage eq 'before') {
        #change pwd for current user and add new user for switch scenario
        x11test::unlock_user_settings;
        change_pwd;
        add_user;
        #verify changed password work well in the following scenario:
        lock_screen;
        turn_off_gnome_screensaver;
        logout_and_login;
        #For poo#88247, it is hard to deal with the authorization of bernhard in
        #following migration process, we have to restore current user's password.
        record_soft_failure("poo#88247, it is hard to deal with the authorization of bernhard in following migration process, we have to restore current users password");
        restore_passwd;
    }
    else {
        #switch to new added user then switch back
        #It's not supported to switch user on s390x VM with vnc connection,
        #so we have to change this test to logout and login new user.
        if (check_var('ARCH', 's390x')) {
            logout_and_login($newUser, $pwd4newUser);
        }
        else {
            switch_users;
        }
        send_key "alt-f4";
        send_key "ret";
        select_console 'root-console';
    }
}

1;
