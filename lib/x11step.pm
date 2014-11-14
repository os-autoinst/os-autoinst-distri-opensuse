package x11step;
use base "opensusebasetest";
use bmwqemu;

# Base class for all X11 tests

sub is_applicable() {
    return x11step_is_applicable;
}

1;
# vim: set sw=4 et:
