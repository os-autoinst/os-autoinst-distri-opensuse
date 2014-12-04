#!/usr/bin/perl -w
use strict;
use base "y2logsstep";

use testapi;

sub run() {
    my $self = shift;
    assert_screen( "scc-registration", 30 );
    if (get_var("SCC_EMAIL") && get_var("SCC_REGCODE") && (!get_var("SCC_REGISTER") || get_var("SCC_REGISTER") eq 'installation')) {
        $self->registering_scc;
    }
    else {
        send_key "alt-s", 1;     # skip SCC registration
        if ( check_screen( "scc-skip-reg-warning", 10 ) ) {
            send_key "alt-y", 1;    # confirmed skip SCC registration
        }
    }
    return 0;
}

1;

# vim: set sw=4 et:
