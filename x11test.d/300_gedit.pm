use base "basetest";
use strict;
use bmwqemu;

# test gedit text editor

# this function decides if the test shall run
sub is_applicable {
    return ( $envs->{DESKTOP} eq "gnome" );
}

# this part contains the steps to run this test
sub run() {
    my $self = shift;
    x11_start_program("gedit");
    type_string "If you can see this text gedit is working.\n";
    sleep 2;
    assert_screen 'test-gedit-1', 3;
    sleep 2;
    send_key "alt-f4";
    sleep 2;
    send_key "alt-w";
    sleep 2;
}

1;
# vim: set sw=4 et:
