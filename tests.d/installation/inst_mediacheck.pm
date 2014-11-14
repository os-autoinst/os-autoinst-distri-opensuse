#!/usr/bin/perl -w
use strict;
use base "y2logsstep";
use bmwqemu;

sub is_applicable() {
    my $self = shift;
    return y2logsstep_is_applicable;
}

sub run() {
    my $self = shift;
    assert_screen("inst-mediacheck");
    send_key $cmd{"next"}, 1;
}

1;
