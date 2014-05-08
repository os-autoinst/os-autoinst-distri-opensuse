use base "basetest";
use strict;
use bmwqemu;

# test xfce4-terminal

# this function decides if the test shall run
sub is_applicable {
    return ( $ENV{DESKTOP} eq "xfce" );
}

# this part contains the steps to run this test
sub run() {
    my $self = shift;
    mouse_hide(1);
    x11_start_program("xfce4-terminal");
    sleep 2;
    send_key "ctrl-shift-t";
    for ( 1 .. 13 ) { send_key "ret" }
    type_string "echo If you can see this text xfce4-terminal is working.\n";
    sleep 2;
    $self->check_screen;
    send_key "alt-f4";
    sleep 2;
    send_key "alt-w";
    sleep 2;    # confirm close of multi-tab window
}

1;
# vim: set sw=4 et:
