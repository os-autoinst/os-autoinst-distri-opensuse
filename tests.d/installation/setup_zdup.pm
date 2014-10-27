use base "installzdupstep";
use strict;
use bmwqemu;

sub run() {
    # wait booted
    assert_screen 'generic-desktop', 200;

    # log into text console
    send_key "ctrl-alt-f4";
    assert_screen "linux-login", 4;
    type_string "$username\n";
    sleep 2;
    sendpassword;
    type_string "\n";
    sleep 3;

    # Remove the graphical stuff
    # This do not work in 13.2
    # script_sudo "/sbin/init 3";

    # Remove the --force when this is fixed:
    # https://bugzilla.redhat.com/show_bug.cgi?id=1075131
    script_sudo "systemctl set-default --force multi-user.target";
    # The CD was ejected in the bootloader test
    script_sudo "/sbin/reboot";

    # login, again : )
    assert_screen "grub2", 10; # boot menu appears
    send_key "ret";
    assert_screen "linux-login", 15; # login prompt appears
    type_string "$username\n";
    sleep 2;
    sendpassword;
    type_string "\n";
    sleep 3;

    # Reloging
    # assert_screen "linux-login", 3;
    # type_string "$username\n";
    # sleep 2;
    # sendpassword;
    # type_string "\n";
    # sleep 3;

    type_string "PS1=\$\n";    # set constant shell promt
    sleep 1;

    # Disable console screensaver
    script_sudo("setterm -blank 0");
}

1;
# vim: set sw=4 et:
