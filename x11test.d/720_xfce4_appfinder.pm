use base "basetest";
use strict;
use bmwqemu;

# test xfce4-appfinder, auto-completion and starting xfce4-about

# this function decides if the test shall run
sub is_applicable {
    return ( $ENV{DESKTOP} eq "xfce" );
}

# this part contains the steps to run this test
sub run() {
    my $self = shift;
    send_key "alt-f2";
    sleep 2;
    send_key "down";
    sendautotype "about\n";
    $self->check_screen;
    send_key "ret", 1;
    $self->check_screen;
    send_key "alt-f4";
    sleep 2;
}

1;
# vim: set sw=4 et:
