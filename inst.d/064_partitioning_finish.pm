#!/usr/bin/perl -w
use strict;
use base "noupdatestep";
use bmwqemu;

sub is_applicable() {
    my $self = shift;
    return $self->SUPER::is_applicable && !$vars{AUTOYAST};
}

sub run() {
    waitstillimage();
    send_key $cmd{"next"};
    assert_screen "after-paritioning";
}

1;
# vim: set sw=4 et:
