use base "y2logsstep";
use strict;
use testapi;

sub run(){
    my $self=shift;

    assert_screen 'novell-customer-center', 30;

    # configure later
    send_key "alt-c";

    sleep 1;
    send_key $cmd{'next'};
}

1;
