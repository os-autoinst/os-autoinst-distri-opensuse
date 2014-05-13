use base "basetest";
use strict;
use bmwqemu;

# test tomboy: already running
# testcase 1248878

# this function decides if the test shall run
sub is_applicable {
    return ( $ENV{DESKTOP} eq "gnome" );
}

# this part contains the steps to run this test
sub run() {
    my $self = shift;

    # open tomboy
    x11_start_program("tomboy note");
    wait_idle;
    assert_screen 'test-tomboy_AlreadyRunning-1', 3;
    sleep 2;
    send_key "alt-f4";
    sleep 2;

    # open again
    x11_start_program("tomboy note");
    wait_idle;
    assert_screen 'test-tomboy_AlreadyRunning-2', 3;
    sleep 2;
    send_key "alt-f4";
    sleep 2;
}

1;
# vim: set sw=4 et:
