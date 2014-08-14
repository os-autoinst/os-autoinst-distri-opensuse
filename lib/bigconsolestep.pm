package bigconsolestep;
use base "consolestep";
use bmwqemu;

sub is_applicable() {
    my $self = shift;
    return $self->SUPER::is_applicable && !$vars{BIGTEST};
}

1;
# vim: set sw=4 et:
