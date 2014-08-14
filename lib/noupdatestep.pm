package noupdatestep;
use base "y2logsstep";

use bmwqemu;

# using this as base class means only run when an install is needed, but no upgrade of an old system
sub is_applicable() {
    my $self = shift;
    return $self->SUPER::is_applicable && !$vars{UPGRADE};
}

1;
# vim: set sw=4 et:
