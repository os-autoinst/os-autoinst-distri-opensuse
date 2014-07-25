package opensusebasetest;
use base "basetest";

# Base class for all openSUSE tests

sub is_applicable() {
    my $self = shift;
    return $self->SUPER::is_applicable;
}

1;
# vim: set sw=4 et:
