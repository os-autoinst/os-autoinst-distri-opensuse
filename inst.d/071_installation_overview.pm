#!/usr/bin/perl -w
use strict;
use base "installstep";
use bmwqemu;

sub is_applicable() {
    return !$envs->{UPGRADE};
}

sub run() {

    # overview-generation
    # this is almost impossible to check for real
    assert_screen  "inst-overview", 15 ;

    # preserve it for the video
    waitidle 10;
}

1;
# vim: set sw=4 et:
