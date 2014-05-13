#!/usr/bin/perl -w
use strict;
use base "installstep";
use bmwqemu;

sub is_applicable() {
    my $self = shift;
    return $self->SUPER::is_applicable && !$envs->{LIVECD} && $envs->{ADDONURL};
}

sub run() {
    my $self = shift;
    if ( $envs->{VIDEOMODE} && $envs->{VIDEOMODE} eq "text" ) { $cmd{xnext} = "alt-x" }
    if ( !$envs->{NET} && !$envs->{DUD} ) {
        waitstillimage();
        sleep 5;                 # try
        send_key $cmd{"next"};    # use network
        waitstillimage(20);
        send_key "alt-o", 1;        # OK DHCP network
    }
    my $repo = 0;
    $repo++ if $envs->{DUD};
    foreach my $url ( split( /\+/, $envs->{ADDONURL} ) ) {
        if ( $repo++ ) { send_key "alt-a", 1; }    # Add another
        send_key $cmd{"xnext"}, 1;                 # Specify URL (default)
        type_string $url;
        send_key $cmd{"next"}, 1;
        if ( $envs->{ADDONURL} !~ m{/update/} ) {    # update is already trusted, so would trigger "delete"
            send_key "alt-i";
            send_key "alt-t", 1;                     # confirm import (trust) key
        }
    }
    assert_screen 'test-addon_product-1', 3;
    send_key $cmd{"next"}, 1;                        # done
}

1;
# vim: set sw=4 et:
