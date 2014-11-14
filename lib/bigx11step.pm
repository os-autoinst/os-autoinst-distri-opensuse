package bigx11step;
use base "x11step";
use bmwqemu;

sub is_applicable() {
    return bigx11step_is_applicable;
}

1;
# vim: set sw=4 et:
