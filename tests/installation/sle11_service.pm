use base "y2logsstep";
use strict;
use testapi;

sub run(){
    my $self=shift;

    check_screen 'network-services', 30;
    send_key $cmd{next};
}


1;
