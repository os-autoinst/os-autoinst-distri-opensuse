use base "y2logsstep";
use strict;
use testapi;

sub run(){
    my $self=shift;

    assert_screen 'release-notes', 100; # suseconfig run
    send_key $cmd{'next'};
}

1;
