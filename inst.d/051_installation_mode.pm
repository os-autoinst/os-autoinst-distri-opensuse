#!/usr/bin/perl -w
use strict;
use base "installstep";
use bmwqemu;

sub is_applicable() {
    my $self = shift;
    return $self->SUPER::is_applicable && !$ENV{LIVECD};
}

sub run() {
    my $self = shift;

    # autoconf phase
    # includes downloads, so waitidle is bad.
    waitforneedle( "inst-instmode", 120 );

    # Installation Mode = new Installation or Upgrade
    if ( $ENV{UPGRADE} ) {
        send_key $cmd{"update"}, 1;
        send_key $cmd{"next"}, 1;
        waitforneedle( "select-for-update", 10 );
    }
    else {
        if ( $ENV{ADDONURL} ) {
            send_key "alt-c";    # Include Add-On Products
            waitforneedle( "addonproduct-included", 10 );
        }
        if ( $ENV{AUTOCONF} ) {
            send_key "alt-s";    # toggle automatic configuration
            waitforneedle( "autoconf-deselected", 10 );
        }
        send_key $cmd{"next"}, 1;
    }
}

1;
# vim: set sw=4 et:
