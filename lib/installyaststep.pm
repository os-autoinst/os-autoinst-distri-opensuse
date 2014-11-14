package installyaststep;
use base "installbasetest";

use bmwqemu;

# using this as base class means only run when an install is needed

sub is_applicable() {
    return installyaststep_is_applicable;
}

1;
# vim: set sw=4 et:
