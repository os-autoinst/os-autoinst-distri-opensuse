use base "installzdupstep";
use strict;
use bmwqemu;

sub run() {
    # wait booted
    sleep 30;
    wait_idle;

    # log into text console
    send_key "ctrl-alt-f4";
    sleep 2;
    type_string "$username\n";
    sleep 2;
    sendpassword;
    type_string "\n";
    sleep 3;

    # Remove the graphical stuff
    script_sudo("/sbin/init 3");

    # Reloging
    assert_screen "linux-login", 3;
    type_string "$username\n";
    sleep 2;
    sendpassword;
    type_string "\n";
    sleep 3;

    type_string "PS1=\$\n";    # set constant shell promt
    sleep 1;

    # Disable console screensaver
    script_sudo("setterm -blank 0");
}

1;
# vim: set sw=4 et:
