use base "installzdupstep";
use strict;
use testapi;

sub run() {
    send_key "ctrl-l", 1;

    # Print zypper repos
    script_sudo "zypper lr -d";
    # Remove the --force when this is fixed:
    # https://bugzilla.redhat.com/show_bug.cgi?id=1075131
    script_sudo "systemctl set-default --force graphical.target";
    sleep 5;

    save_screenshot;

    # Reboot after dup
    send_key "ctrl-alt-delete";
    assert_screen "grub2", 50;

    # Wait until the point that consoletests can start working
    assert_screen "desktop-at-first-boot", 400;
}

1;
# vim: set sw=4 et:
