package consolestep;
use base "opensusebasetest";
use bmwqemu;

# Base class for all console tests

sub is_applicable() {
    return consolestep_is_applicable;
}

1;
# vim: set sw=4 et:
