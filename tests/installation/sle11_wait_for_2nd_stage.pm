use base "y2logsstep";
use strict;
use testapi;

sub run(){
    my $self=shift;

    assert_screen "second-stage", 50;
    mouse_hide;

}

1;
