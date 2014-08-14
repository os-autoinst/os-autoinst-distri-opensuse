package installyaststep;
use base "installbasetest";

use bmwqemu;

# using this as base class means only run when an install is needed
sub is_applicable() {
    my $self = shift;
    return $self->SUPER::is_applicable && !$vars{NOINSTALL} && !$vars{LIVETEST} && !$vars{MEMTEST} && !$vars{ZDUP};
}

1;
# vim: set sw=4 et:
