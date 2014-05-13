#!/usr/bin/perl -w
use strict;
use base "installstep";
use bmwqemu;

sub is_applicable() {
    my $self = shift;
    return $self->SUPER::is_applicable && !$ENV{LIVECD} && !$ENV{UPGRADE};
}

sub run() {
    my $self = shift;

    # autoconf phase
    # includes downloads, so wait_idle is bad.
    assert_screen  "inst-instmode", 120 ;

    if ( $ENV{ADDONURL} ) {
        send_key "alt-c";    # Include Add-On Products
        assert_screen  "addonproduct-included", 10 ;
    }
    if ( $ENV{AUTOCONF} ) {
        send_key "alt-s";    # toggle automatic configuration
        assert_screen  "autoconf-deselected", 10 ;
    }
    send_key $cmd{"next"}, 1;
}

1;
# vim: set sw=4 et:
