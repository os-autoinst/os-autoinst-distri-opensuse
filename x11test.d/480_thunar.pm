use base "basetest";
use strict;
use bmwqemu;

# test thunar and open the root directory

# this function decides if the test shall run
sub is_applicable {
    return ( $ENV{DESKTOP} eq "xfce" );
}

# this part contains the steps to run this test
sub run() {
    my $self = shift;
    x11_start_program("thunar");
    sleep 10;
    send_key "shift-tab";
    send_key "home";
    send_key "down";
    assert_screen 'test-thunar-1', 3;
    send_key "alt-f4";
    sleep 2;
}

1;
# vim: set sw=4 et:
