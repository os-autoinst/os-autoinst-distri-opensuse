use strict;
use base "y2logsstep";
use bmwqemu;

sub run() {
    my $self = shift;

    assert_screen( "grub2", 900 );
}

1;
