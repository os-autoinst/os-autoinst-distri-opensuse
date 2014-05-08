#!/usr/bin/perl -w
use strict;
use base "installstep";
use bmwqemu;

sub is_applicable() {
    my $self = shift;
    return $self->SUPER::is_applicable && !$ENV{LIVECD} && $ENV{ADDONURL};
}

sub run() {
    my $self = shift;
    if ( $ENV{VIDEOMODE} && $ENV{VIDEOMODE} eq "text" ) { $cmd{xnext} = "alt-x" }
    if ( !$ENV{NET} && !$ENV{DUD} ) {
        waitstillimage();
        sleep 5;                 # try
        send_key $cmd{"next"};    # use network
        waitstillimage(20);
        send_key "alt-o", 1;        # OK DHCP network
    }
    my $repo = 0;
    $repo++ if $ENV{DUD};
    foreach my $url ( split( /\+/, $ENV{ADDONURL} ) ) {
        if ( $repo++ ) { send_key "alt-a", 1; }    # Add another
        send_key $cmd{"xnext"}, 1;                 # Specify URL (default)
        type_string $url;
        send_key $cmd{"next"}, 1;
        if ( $ENV{ADDONURL} !~ m{/update/} ) {    # update is already trusted, so would trigger "delete"
            send_key "alt-i";
            send_key "alt-t", 1;                     # confirm import (trust) key
        }
    }
    $self->check_screen;
    send_key $cmd{"next"}, 1;                        # done
}

1;
# vim: set sw=4 et:
