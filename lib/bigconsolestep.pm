package bigconsolestep;
use base "consolestep";
use bmwqemu;

sub is_applicable() {
    return bigconsolestep_is_applicable;
}

1;
# vim: set sw=4 et:
