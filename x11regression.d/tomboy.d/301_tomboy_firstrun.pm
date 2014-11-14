use base "basetest";
use strict;
use bmwqemu;

# test tomboy first run
# testcase 1248872

# this part contains the steps to run this test
sub run() {
    my $self = shift;
    mouse_hide();
    x11_start_program("tomboy note");
    while ( check_screen "tomboy_command_not_found", 5  ) {
        sleep 30;
        send_key "ret";
        sleep 1;
    }
    sleep 1;

    # open the menu
    send_key "alt-f12";
    sleep 2;
    check_screen "tomboy_menu", 5;
    sleep 2;
    send_key "esc";
    sleep 3;
    send_key "alt-f4";
    sleep 7;
    wait_idle;
}

1;
# vim: set sw=4 et:
