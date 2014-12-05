#!/usr/bin/perl -w
use strict;
use base "y2logsstep";
use testapi;

sub run() {
    my $self = shift;

    # on sle11 this is the first screen of 2nd stage, so hide the mouse
    # does not harm on other distributions either
    mouse_hide;

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
