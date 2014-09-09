package rescuecdstep;
use base "opensusebasetest";
use bmwqemu;

# Base class for all RESCUECD tests

sub is_applicable() {
    my $self = shift;
    return $self->SUPER::is_applicable && $vars{RESCUECD};
}

sub test_flags() {
    return { 'important' => 1, 'fatal' => 1 };
}

1;
# vim: set sw=4 et:
