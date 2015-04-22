use base "y2logsstep";
use strict;
use testapi;

sub run(){
    my $self=shift;

    assert_screen "second-stage", 250;

    # mouse is tricky to move, punch the mouse 8 times
    for my $i (0..8) {
        wait_idle;
        mouse_hide;
    }
}

1;
