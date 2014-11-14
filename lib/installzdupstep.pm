package installzdupstep;
use base "installbasetest";

use bmwqemu;

sub is_applicable() {
    return installzdupstep_is_applicable;
}

1;
# vim: set sw=4 et:
