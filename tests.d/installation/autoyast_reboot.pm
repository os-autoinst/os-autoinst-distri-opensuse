use strict;
use base "y2logsstep";
use bmwqemu;

sub is_applicable() {
    my $self = shift;
    $self->SUPER::is_applicable && $vars{AUTOYAST};
}

sub run() {
    my $self = shift;

    assert_screen( "grub2", 900 );
}

1;
