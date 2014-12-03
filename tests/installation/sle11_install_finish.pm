use base "y2logsstep";
use strict;
use testapi;

sub run(){
    my $self=shift;

    # long timeout for hardware detection to finish
    assert_screen 'install-completed', 40;
    send_key $cmd{'finish'};
}

1;
