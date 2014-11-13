#!/usr/bin/perl -w
use strict;
use base "y2logsstep";
use bmwqemu;

sub is_applicable() {
    my $self = shift;
    return $self->SUPER::is_applicable && !$vars{LIVECD} && !$vars{AUTOYAST};
}

sub run() {
    my $self = shift;
    assert_screen 'inst-addon', 3;
    send_key $cmd{"next"}, 1;    # done

    if (check_screen("local-registration-servers", 10)) {
        send_key $cmd{ok};
    }
}

1;
# vim: set sw=4 et:
