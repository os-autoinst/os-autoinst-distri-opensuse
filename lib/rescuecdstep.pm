package rescuecdstep;
use base "opensusebasetest";
use bmwqemu;

# Base class for all RESCUECD tests

sub test_flags() {
    return { 'important' => 1, 'fatal' => 1 };
}

sub is_applicable() {
    return rescuecdstep_is_applicable;
}

1;
# vim: set sw=4 et:
