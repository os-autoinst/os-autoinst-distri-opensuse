use base "y2logsstep";
use strict;
use testapi;

sub run(){
    my $self=shift;
    if ( get_var("ENCRYPT") ){
        $self->pass_disk_encrypt_check;
    }
    assert_screen "second-stage", 250;
    mouse_hide;
    sleep 1;
    mouse_hide;

}

1;
