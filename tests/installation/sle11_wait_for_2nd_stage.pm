use base "y2logsstep";
use strict;
use testapi;

sub run(){
    my $self=shift;

    assert_screen "inst-rootpassword", 50;
    mouse_hide;

}

1;
