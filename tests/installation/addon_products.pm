#!/usr/bin/perl -w
use strict;
use base "y2logsstep";
use testapi;

sub run() {
    my $self = shift;
    if ( $vars{VIDEOMODE} && check_var("VIDEOMODE", "text") ) { $cmd{xnext} = "alt-x" }
    if ( !$vars{NET} && !$vars{DUD} ) {
        waitstillimage();
        sleep 5;                 # try
        send_key $cmd{"next"};    # use network
        waitstillimage(20);
        send_key "alt-o", 1;        # OK DHCP network
    }
    my $repo = 0;
    $repo++ if $vars{DUD};
    foreach my $url ( split( /\+/, $vars{ADDONURL} ) ) {
        if ( $repo++ ) { send_key "alt-a", 1; }    # Add another
        send_key $cmd{"xnext"}, 1;                 # Specify URL (default)
        type_string $url;
        send_key $cmd{"next"}, 1;
        if ( $vars{ADDONURL} !~ m{/update/} ) {    # update is already trusted, so would trigger "delete"
            send_key "alt-i";
            send_key "alt-t", 1;                     # confirm import (trust) key
        }
    }
    assert_screen 'test-addon_product-1', 3;
    send_key $cmd{"next"}, 1;                        # done
}

1;
# vim: set sw=4 et:
