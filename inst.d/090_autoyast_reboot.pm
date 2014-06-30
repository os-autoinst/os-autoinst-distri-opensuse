use strict;
use base "installstep";
use bmwqemu;

sub is_applicable() {
    my $self = shift;
    $self->SUPER::is_applicable && $vars{AUTOYAST};
}

sub run() {
    my $self = shift;

    my @tags = qw/inst-bootmenu grub2/;
    assert_screen( \@tags, 900 );
}

1;
