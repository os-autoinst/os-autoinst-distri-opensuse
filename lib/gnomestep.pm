package gnomestep;
use base "x11step";
use bmwqemu;

sub is_applicable() {
    return gnomestep_is_applicable;
}

1;
# vim: set sw=4 et:
