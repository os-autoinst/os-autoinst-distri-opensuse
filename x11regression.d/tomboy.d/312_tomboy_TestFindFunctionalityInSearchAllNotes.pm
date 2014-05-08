use base "basetest";
use strict;
use bmwqemu;

# test tomboy: what links here
# testcase 1248883

# this function decides if the test shall run
sub is_applicable {
    return ( $ENV{DESKTOP} eq "gnome" );
}

# this part contains the steps to run this test
sub run() {
    my $self = shift;

    # open tomboy
    x11_start_program("tomboy note");

    # create a note
    send_key "ctrl-n";
    sleep 2;
    sendautotype "hehe";
    sleep 1;
    send_key "alt-f4";
    waitidle;

    send_key "alt-f9";
    sleep 2;
    sendautotype "hehe";
    sleep 1;
    $self->check_screen;
    sleep 2;
    send_key "alt-f4";
    waitidle;

    # test Edit->preferences
    send_key "alt-f9";
    sleep 2;
    send_key "alt-e";
    sleep 1;
    send_key "p";
    sleep 1;
    $self->check_screen;
    sleep 2;
    send_key "alt-f4";
    sleep 1;
    send_key "alt-f4";
    waitidle;

    # test Help->Contents
    send_key "alt-f9";
    sleep 2;
    send_key "alt-h";
    sleep 1;
    send_key "c";
    sleep 1;
    $self->check_screen;
    sleep 2;
    send_key "alt-f4";
    sleep 1;
    send_key "alt-f4";
    waitidle;

    # test Help-> About
    send_key "alt-f9";
    sleep 2;
    send_key "alt-h";
    send_key "a";
    sleep 1;
    $self->check_screen;
    sleep 2;
    send_key "alt-f4";
    sleep 1;
    send_key "alt-f4";
    waitidle;

    # test File->Close
    send_key "alt-f";
    sleep 1;
    send_key "c";
    sleep 1;
    $self->check_screen;
    sleep 2;

    # delete the created note
    send_key "alt-f9";
    sleep 1;
    send_key "up";
    sleep 1;
    send_key "delete";
    sleep 1;
    send_key "alt-d";
    sleep 1;
    send_key "alt-f4";
    waitidle;
}

1;
# vim: set sw=4 et:
