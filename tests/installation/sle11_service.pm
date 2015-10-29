use base "y2logsstep";
use strict;
use testapi;

sub run() {
    my $self = shift;

    assert_screen 'network-services', 30;
    sleep 2;
    send_key $cmd{next};
}


1;
