use base "y2logsstep";
use strict;
use testapi;

sub run(){
    my $self=shift;

    assert_screen 'install-completed', 5;
    send_key $cmd{'finish'};
}

1;
