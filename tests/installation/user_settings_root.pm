#!/usr/bin/perl -w
use strict;
use base "noupdatestep";
use testapi;

sub run() {
    my $self = shift;

    assert_screen "inst-rootpassword", 6;
    for ( 1 .. 2 ) {
        type_string "$password\t";
        sleep 1;
    }
    assert_screen "rootpassword-typed", 3;
    send_key $cmd{"next"};

    # PW too easy (cracklib)
    assert_screen "inst-userpasswdtoosimple", 10;
    send_key "ret";
}

1;
# vim: set sw=4 et:
