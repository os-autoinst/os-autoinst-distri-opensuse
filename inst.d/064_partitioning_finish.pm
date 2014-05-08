#!/usr/bin/perl -w
use strict;
use base "basenoupdate";
use bmwqemu;

sub is_applicable() {
    my $self = shift;
    return $self->SUPER::is_applicable && !$ENV{UPGRADE};
}

sub run() {
    waitstillimage();
    send_key $cmd{"next"};
    waitforneedle("after-paritioning");
}

1;
# vim: set sw=4 et:
