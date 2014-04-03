#!/usr/bin/perl -w
use strict;
use base "basenoupdate";
use bmwqemu;

sub is_applicable() {
    my $self = shift;
    return $self->SUPER::is_applicable && !$ENV{LIVECD};
}

sub run() {
    waitforneedle( "inst-timezone", 125 ) || die 'no timezone';
    sendkey $cmd{"next"};
}

1;
