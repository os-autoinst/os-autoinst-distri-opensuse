#!/usr/bin/perl -w
use strict;
use base "noupdatestep";
use bmwqemu;

sub is_applicable() {
    my $self = shift;
    return 0;    # XXX fix test
    return $self->SUPER::is_applicable && $vars{DVD} && $vars{NOIMAGES};
}

sub run() {
    send_key $cmd{change};    # Change
    sleep 3;
    my $images = ( $vars{VIDEOMODE} eq "text" ) ? "alt-i" : "i";
    send_key $images;         # Images
    sleep 10;
}

1;
# vim: set sw=4 et:
