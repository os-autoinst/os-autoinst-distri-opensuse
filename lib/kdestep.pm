package kdestep;
use base "x11step";
use bmwqemu;

sub is_applicable() {
    return kdestep_is_applicable;
}

1;
# vim: set sw=4 et:
