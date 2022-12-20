# SUSE's openQA tests
#
# Copyright 2016-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: gdm gnome-settings-daemon
# Summary: in GNOME, change password for current user and check that it's
# accepted everywhere. Create then a new user and login with it.
# - change password for current user
# - add new user
# - lock and unlock screen for current user
# - logout and login with current user
# - switch to the newly created user
# - login with the new user
# - switch back to original user
# - restore password to its original value
# Maintainer: chuchingkai <chuchingkai@gmail.com>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;
use power_action_utils 'reboot_x11';
use version_utils;
use x11utils;
use main_common 'opensuse_welcome_applicable';
use services::users;

#testcase 5255-1503803: Gnome:Change Password

sub reboot_system {
    my ($self) = @_;
    reboot_x11;
    if (check_var('NOAUTOLOGIN', 1)) {
        $self->{await_reboot} = 1;
        $self->wait_boot(nologin => 1);
        assert_screen "displaymanager", 200;
        $self->{await_reboot} = 0;
        assert_and_click "displaymanager-$username";
        wait_still_screen;
        enter_cmd "$services::users::newpwd";
    } else {
        $self->wait_boot();
    }
    handle_gnome_activities;
}

sub auto_login_alter {
    my ($self) = @_;
    $self->unlock_user_settings;
    send_key "alt-u";
    send_key "alt-f4";
}

sub run {
    my ($self) = @_;

    #change pwd for current user and add new user for switch scenario
    assert_screen "generic-desktop";
    $self->unlock_user_settings;
    services::users::change_pwd();
    services::users::add_user();
    #verify changed password work well in the following scenario:
    services::users::lock_screen();
    services::users::logout_and_login();
    $self->reboot_system;
    if (is_tumbleweed && !get_var('NOAUTOLOGIN')) {
        set_var('NOAUTOLOGIN', 1);
        $self->auto_login_alter;
    }

    #switch to new added user then switch back
    services::users::switch_users();

    #restore password to original value
    services::users::restore_passwd();

    send_key "alt-f4";
    send_key "ret";

    if (is_tumbleweed && get_var('NOAUTOLOGIN')) {
        set_var('NOAUTOLOGIN', '');
        $self->auto_login_alter;
    }
}

1;
