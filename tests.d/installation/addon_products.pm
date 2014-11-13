#!/usr/bin/perl -w
use strict;
use base "installstep";
use bmwqemu;

sub is_applicable() {
    my $self = shift;
    $self->SUPER::is_applicable && !$vars{AUTOYAST};
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
