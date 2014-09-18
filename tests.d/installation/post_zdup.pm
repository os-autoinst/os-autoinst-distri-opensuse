use base "installzdupstep";
use strict;
use bmwqemu;

sub run() {
    send_key "ctrl-l", 1;

    script_sudo "zypper lr -d"; # print zypper repos
    script_sudo "systemctl set-default --force graphical.target"; # set back runlevel 5 to default
    save_screenshot;
    # reboot after dup
    send_key "ctrl-alt-f4", 1;
    send_key "ctrl-alt-delete";
    assert_screen "bootloader", 50;
}

1;
# vim: set sw=4 et:
