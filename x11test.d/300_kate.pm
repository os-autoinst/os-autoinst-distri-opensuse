use base "basetest";
use strict;
use bmwqemu;

# test kde text editor

# this function decides if the test shall run
sub is_applicable {
    return ( $vars{DESKTOP} eq "kde" );
}

# this part contains the steps to run this test
sub run() {
    my $self = shift;
    ensure_installed("kate");
    x11_start_program("kate");
    assert_screen 'test-kate-1', 10;

    # close welcome screen
    send_key 'alt-c';
    sleep 2;
    type_string "If you can see this text kate is working.\n";
    assert_screen 'test-kate-2', 5;
    send_key "ctrl-q";
    assert_screen 'test-kate-3', 5;
    send_key "alt-d"; # discard
}

1;
# vim: set sw=4 et:
