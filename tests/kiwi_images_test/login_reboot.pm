# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Login and reboot a kiwi image
# - at login screen, type user and password
# - after login, reboots machine
# - makes sure image rebooted and is at login screen again
# Maintainer: Ednilson Miura <emiura@suse.com>

use base "installbasetest";
use strict;
use warnings;
use testapi;
use utils;
use version_utils "is_sle";

sub run {
    # login
    type_string("root\n");
    sleep(2);
    type_password("linux\n");
    # and reboot
    type_string("reboot\n");
    # bootloader screen is too fast for openqa
    sleep(10);
    send_key 'down';
    send_key 'up';
    assert_screen('kiwi_boot', 120);
    send_key 'ret';
    assert_screen('linux-login', 120);
}
1;
