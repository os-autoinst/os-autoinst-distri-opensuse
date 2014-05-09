use base "basetest";
use strict;
use bmwqemu;

# test kde text editor

# this function decides if the test shall run
sub is_applicable {
    return ( $ENV{DESKTOP} eq "kde" );
}

# this part contains the steps to run this test
sub run() {
    my $self = shift;
    ensure_installed("kate");
    x11_start_program("kate");
    assert_screen 'test-kate-1', 3;

    # close welcome screen
    send_key 'alt-c';
    sleep 2;
    type_string "If you can see this text kate is working.\n";
    sleep 2;
    assert_screen 'test-kate-2', 3;
    send_key "ctrl-q";
    sleep 2;
    assert_screen 'test-kate-3', 3;
    send_key "alt-d";
    sleep 2;    # discard
}

1;
# vim: set sw=4 et:
