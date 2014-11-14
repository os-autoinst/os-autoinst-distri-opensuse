#!/usr/bin/perl -w
use strict;
use base "noupdatestep";
use bmwqemu;

sub is_applicable() {
    my $self = shift;
    return noupdatestep_is_applicable && !$vars{AUTOYAST};
}

sub run() {

    # overview-generation
    # this is almost impossible to check for real
    assert_screen "inst-overview", 15;

    # preserve it for the video
    wait_idle 10;
}

1;
# vim: set sw=4 et:
