#!/usr/bin/perl -w
use strict;
use base "noupdatestep";
use bmwqemu;

sub run() {
    my $self = shift;

    wait_idle;
    for ( 1 .. 2 ) {
        type_string "$password\t";
        sleep 1;
    }
    assert_screen "rootpassword-typed", 3;
    send_key $cmd{"next"};

    # loading cracklib
    wait_idle 6;

    # PW too easy (cracklib)
    send_key "ret";
    wait_idle;
}
