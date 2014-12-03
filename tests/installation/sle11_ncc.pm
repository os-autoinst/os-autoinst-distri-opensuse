use base "y2logsstep";
use strict;
use testapi;

sub run(){
    my $self=shift;

    check_screen 'novell-customer-center', 10;

    # configure later
    send_key "alt-c";

    sleep 1;
    send_key $cmd{'next'};
}

1;
