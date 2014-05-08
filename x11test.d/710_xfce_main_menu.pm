use base "basetest";
use strict;
use bmwqemu;

# take a snapshot of every submenu of the main menu, allows spotting incorrect
# categories, ugly icons, or unwanted dependencies

# this function decides if the test shall run
sub is_applicable {
    return 0;
    return ( $ENV{DESKTOP} eq "xfce" );
}

# this part contains the steps to run this test
sub run() {
    my $self = shift;
    send_key "alt+f1";
    sleep 2;
    for ( 1 .. 8 ) {
        send_key "down";
        sleep 1;
        $self->check_screen;
        sleep 1;
    }
    send_key "esc";
}

1;
# vim: set sw=4 et:
