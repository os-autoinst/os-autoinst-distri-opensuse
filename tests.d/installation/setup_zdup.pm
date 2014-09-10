use base "installzdupstep";
use strict;
use bmwqemu;

sub run() {
    # wait booted
    sleep 30;
    wait_idle;

    # log into text console
    send_key "ctrl-alt-f4";
    assert_screen "linux-login", 2;
    type_string "$username\n";
    sleep 2;
    sendpassword;
    type_string "\n";
    sleep 3;

    # Remove the graphical stuff
    # This do not work in 13.2
    # script_sudo "/sbin/init 3";

    script_sudo "systemctl set-default multi-user.target";
    # The CD was ejected in the bootloader test
    script_sudo "/sbin/reboot";

    # login, again : )
    assert_screen "linux-login", 30;
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
