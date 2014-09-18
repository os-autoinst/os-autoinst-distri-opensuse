use base "installzdupstep";
use strict;
use bmwqemu;

sub run() {
    send_key "ctrl-l", 1;

    script_sudo "zypper lr -d"; # print zypper repos
    script_sudo "systemctl set-default --force graphical.target"; # set back runlevel 5 to default
    sleep 5;
    save_screenshot;
    # reboot after dup
    send_key "ctrl-alt-f4";
    assert_screen "tty4-selected", 10;
    send_key "ctrl-alt-delete";
    assert_screen "bootloader", 50;
}

1;
# vim: set sw=4 et:
