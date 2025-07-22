# SUSE's openQA tests
#
# Copyright 2016-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: gdm gnome-terminal nautilus
# Summary: Add a case for gdm session switch
#    openSUSE has shipped SLE-Classic since Leap 42.2, this case will test
#    gdm session switch among sle-classic, gnome-classic, icewm and gnome.
#    Also test rebooting from login screen.
# Maintainer: Chingkai Chu <chuchingkai@gmail.com>

use base "x11test";
use testapi;
use utils;
use version_utils 'is_sle';
use x11utils 'handle_gnome_activities';

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

    # Reboot and log in
    $self->switch_wm;
    assert_and_click "displaymanager-systembutton";
    assert_and_click "displaymanager-system-powerbutton";
    assert_and_click "displaymanager-reboot";
    assert_and_click "confirm-restart" if (is_sle('>=15-SP4'));

    if (get_var("SHUTDOWN_NEEDS_AUTH")) {
        assert_screen 'reboot-auth', 15;
        type_password;
        send_key "ret";
    }

    $self->wait_boot(bootloader_time => 300);

    # Log out and log in again
    $self->switch_wm;
    send_key "ret";
    handle_gnome_activities;

    # Log out and switch to icewm
    $self->switch_wm;
    assert_and_click "displaymanager-settings";
    assert_and_click "dm-icewm";
    send_key "ret";
    assert_screen "desktop-icewm";
    # Smoke test: launch some applications
    send_key "super-spc";
    wait_still_screen(2);
    enter_cmd "gnome-terminal";
    assert_screen "gnome-terminal";
    send_key "alt-f4";
    send_key "super-spc";
    wait_still_screen(2);
    enter_cmd "nautilus";
    assert_screen "test-nautilus-1";
    send_key "alt-f4";
    wait_still_screen;

    # Log out and switch back to GNOME(default)
    send_key "ctrl-alt-delete";
    assert_screen "icewm-session-dialog";
    send_key "alt-l";
    wait_still_screen(2);
    send_key "alt-o";
    $self->dm_login;
    assert_and_click "displaymanager-settings";
    assert_and_click "dm-gnome";
    send_key "ret";
    handle_gnome_activities;

    # Log out and switch to SLE classic
    $self->prepare_sle_classic;
    $self->application_test;
}

1;
