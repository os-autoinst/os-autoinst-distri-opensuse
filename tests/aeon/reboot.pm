# SUSE's openQA tests
#
# Copyright SUSE LLC and contributors
# SPDX-License-Identifier: FSFAP

# Summary: Test Aeon reboot and login

# Maintainer: Jan-Willem Harmannij <jwharmannij at gmail com>

use Mojo::Base 'basetest';
use testapi;
use utils;

sub run {
    # Open GNOME Shell overview
    send_key 'super' unless (check_screen 'gnome-shell-overview');
    assert_screen 'gnome-shell-overview';

    # Initiate reboot
    type_string 'reboot';
    assert_and_click 'gnome-shell-confirm-reboot-1';
    assert_and_click 'gnome-shell-confirm-reboot-2';
    
    # Input the encryption passphrase
    assert_screen 'aeon-boot-enter-passphrase', 600;
    type_string $testapi::password;
    send_key 'ret';

    # Aeon will boot and show the login screen
    assert_screen 'login-1', 600;
    assert_and_click 'login-1';
    assert_screen 'login-2';
    type_string $testapi::password;
    send_key 'ret';

    # Wait until the GNOME Shell overview is visible again
    assert_screen 'gnome-shell-overview';
}

1;
