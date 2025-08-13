# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Login and reboot a kiwi image
# - at login screen, type user and password
# - after login, reboots machine
# - makes sure image rebooted and is at login screen again
# Maintainer: Ednilson Miura <emiura@suse.com>

use base "installbasetest";
use testapi;
use utils;

sub run {
    # login
    enter_cmd("root");
    sleep(2);
    type_password("linux\n");
    # and reboot
    enter_cmd("reboot");
    # bootloader screen is too fast for openqa
    sleep(10);
    send_key 'down';
    send_key 'up';
    assert_screen('kiwi_boot', 120);
    send_key 'ret';
    assert_screen('linux-login', 120);
}
1;
