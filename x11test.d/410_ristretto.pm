use base "basetest";
use strict;
use bmwqemu;

# test ristretto and open the default wallpaper

# this function decides if the test shall run
sub is_applicable {
    return ( $ENV{DESKTOP} eq "xfce" );
}

# this part contains the steps to run this test
sub run() {
    my $self = shift;
    x11_start_program("ristretto /usr/share/wallpapers/xfce/default.wallpaper");
    send_key "ctrl-m";
    sleep 2;
    $self->check_screen;
    send_key "alt-f4";
    sleep 2;
}

1;
# vim: set sw=4 et:
