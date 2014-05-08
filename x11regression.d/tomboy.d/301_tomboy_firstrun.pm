use base "basetest";
use strict;
use bmwqemu;

# test tomboy first run
# testcase 1248872

# this function decides if the test shall run
sub is_applicable {
    return ( $ENV{DESKTOP} eq "gnome" );
}

# this part contains the steps to run this test
sub run() {
    my $self = shift;
    mouse_hide();
    x11_start_program("tomboy note");
    while ( checkneedle( "tomboy_command_not_found", 5 ) ) {
        sleep 30;
        send_key "ret";
        sleep 1;
    }
    sleep 1;

    # open the menu
    send_key "alt-f12";
    sleep 2;
    checkneedle( "tomboy_menu", 5 );
    sleep 2;
    send_key "esc";
    sleep 3;
    send_key "alt-f4";
    sleep 7;
    waitidle;
}

1;
# vim: set sw=4 et:
