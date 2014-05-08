use base "basetest";
use strict;
use bmwqemu;

# test gnome-terminal

# this function decides if the test shall run
sub is_applicable {
    return ( $ENV{DESKTOP} eq "gnome" );
}

# this part contains the steps to run this test
sub run() {
    my $self = shift;
    mouse_hide(1);
    x11_start_program("gnome-terminal");
    sleep 2;
    send_key "ctrl-shift-t";
    for ( 1 .. 13 ) { send_key "ret" }
    sendautotype("echo If you can see this text gnome-terminal is working.\n");
    sleep 2;
    $self->check_screen;
    sleep 2;
    send_key "alt-f4";
    sleep 2;
}

1;
# vim: set sw=4 et:
