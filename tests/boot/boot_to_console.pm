use base "basetest";
use strict;
use testapi;
use Time::HiRes qw(sleep);

sub run() {
    assert_screen "inst-bootmenu", 30;
    sleep 2;
    send_key "ret";    # boot

    assert_screen "grub2", 15;
    sleep 1;
    send_key "ret";

    assert_screen "displaymanager", 200;
    mouse_hide(1);
    # do not login to desktop to reduce possibility of blocking zypper by packagekitd
    # and directly switch to text console
    send_key "ctrl-alt-f1";
    assert_screen "tty1-selected", 15;

    send_key "ctrl-alt-f4";
    assert_screen "tty4-selected", 10;
    assert_screen "text-login", 10;
    type_string "$username\n";
    assert_screen "password-prompt", 10;
    type_password;
    type_string "\n";
    sleep 1;

    # Disable console screensaver
    script_run("setterm -blank 0");
}

sub test_flags() {
    return { 'fatal' => 1 };
}

1;
# vim: set sw=4 et:
