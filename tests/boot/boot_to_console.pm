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
    select_console 'user-console';
    sleep 1;

    # Disable console screensaver
    script_run("setterm -blank 0");
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
