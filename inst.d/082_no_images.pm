#!/usr/bin/perl -w
use strict;
use base "basenoupdate";
use bmwqemu;

sub is_applicable() {
    my $self = shift;
    return 0;    # XXX fix test
    return $self->SUPER::is_applicable && $ENV{DVD} && $ENV{NOIMAGES};
}

sub run() {
    send_key $cmd{change};    # Change
    sleep 3;
    my $images = ( $ENV{VIDEOMODE} eq "text" ) ? "alt-i" : "i";
    send_key $images;         # Images
    sleep 10;
}

1;
# vim: set sw=4 et:
