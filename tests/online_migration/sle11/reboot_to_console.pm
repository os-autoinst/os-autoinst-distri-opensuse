# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: sle11 online migration testsuite
# G-Maintainer: mitiao <mitiao@gmail.com>

use base "basetest";
use strict;
use testapi;
use Time::HiRes qw(sleep);

sub run() {
    type_string "reboot\n";
    check_screen "machine-is-shutdown", 30;
    assert_screen "grub2",              100;    # wait until reboot
    sleep 1;
    send_key "ret";

    assert_screen "displaymanager", 200;
    type_string $username. "\n";
    sleep 1;
    type_string $password. "\n";

    assert_screen 'generic-desktop', 300;
    mouse_hide(1);

    # switch to text console
    wait_idle;
    save_screenshot;
    send_key "ctrl-alt-f1";
    assert_screen "tty1-selected", 15;

    send_key "ctrl-alt-f4";
    assert_screen "tty4-selected", 10;
    assert_screen "text-login",    10;
    type_string "$username\n";
    assert_screen "password-prompt", 10;
    type_password;
    type_string "\n";
    sleep 1;
}

1;
# vim: set sw=4 et:
