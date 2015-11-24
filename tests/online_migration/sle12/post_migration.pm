use base "installbasetest";
use strict;
use testapi;
use utils;

sub run() {
    send_key "ctrl-l", 1;

    # print repos to screen and serial console after online migration
    script_run("zypper lr -u | tee /dev/$serialdev");
    save_screenshot;

    # reboot to upgraded system after online migration
    send_key "ctrl-alt-f3";
    assert_screen "text-login", 5;
    send_key "ctrl-alt-delete";
    wait_boot;
}

1;
# vim: set sw=4 et:
