use base "y2logsstep";
use strict;
use testapi;

sub run(){
    my $self=shift;

    assert_screen 'user-authentification-method', 10;
    send_key $cmd{next};
}

1;
