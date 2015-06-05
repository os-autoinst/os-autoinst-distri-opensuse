use base "y2logsstep";
use strict;
use testapi;

sub run(){
    my $self=shift;

    assert_screen 'ncc-online-update', 30;

    # Skip update 
    send_key "alt-s";
    sleep 1;
    send_key $cmd{'next'};
}

1;
