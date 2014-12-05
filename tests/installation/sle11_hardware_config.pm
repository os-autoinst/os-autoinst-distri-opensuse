use base "y2logsstep";
use strict;
use testapi;

sub run(){
    my $self=shift;

    assert_screen 'hardware-config', 80;
    send_key $cmd{'next'};
}

1;
