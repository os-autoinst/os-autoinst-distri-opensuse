use base "y2logsstep";
use strict;
use testapi;

sub run(){
    my $self=shift;

    # long timeout for hardware detection to finish
    assert_screen 'install-completed', 40;
    if ( get_var('WORKAROUND_BOO926960') ) {
        send_key 'alt-c', 3;
    }
    send_key $cmd{'finish'};
}

1;
