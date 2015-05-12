require "change_desktop.pm";
push @ISA, 'change_desktop';
use strict;
use testapi;

sub run {
    my ($self) = @_;

    $self->change_desktop();
}

1;
# vim: set sw=4 et:
