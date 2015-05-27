#!/usr/bin/perl -w
use strict;
use base "y2logsstep";
use testapi;

sub run() {
    my $self = shift;

    send_key('alt-n', 3) if (check_screen("dud-found", 3));
}

1;
# vim: set sw=4 et:
