use base "basetest";
use strict;
use testapi;

# test tomboy: open
# testcase 1248874

# this part contains the steps to run this test
sub run() {
    my $self = shift;

    # open start note and take screenshot
    x11_start_program("tomboy note");
    send_key "alt-f11";
    sleep 2;
    send_key "ctrl-home";
    sleep 2;
    type_string "Rename_";
    sleep 1;
    send_key "ctrl-w";
    wait_idle;

    # Check hotkey for open "start here" still works
    send_key "alt-fll";
    sleep 2;
    wait_still_screen;
    check_screen "tomboy_open_0", 5;

    send_key "shift-up";
    sleep 2;
    send_key "delete";
    sleep 2;
    send_key "ctrl-w";
    sleep 2;
    send_key "alt-f4";
    sleep 2;

    # logout
    send_key "alt-f2";
    sleep 1;
    type_string "gnome-session-quit --logout --force\n";
    sleep 20;
    wait_idle;

    # login
    send_key "ret";
    sleep 2;
    wait_still_screen;
    type_password();
    sleep 2;
    send_key "ret";
    sleep 20;
    wait_idle;

    # open start note again and take screenshot
    x11_start_program("tomboy note");
    send_key "alt-f11";
    sleep 2;
    send_key "up";
    sleep 1;
    check_screen "tomboy_open_1", 5;
    send_key "ctrl-w";
    sleep 2;
    send_key "alt-f4";
    sleep 2;
    wait_idle;
}

1;
# vim: set sw=4 et:
