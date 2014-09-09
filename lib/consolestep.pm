package consolestep;
use base "opensusebasetest";
use bmwqemu;

# Base class for all console tests

sub is_applicable() {
    my $self = shift;
    return $self->SUPER::is_applicable && !$vars{INSTALLONLY} && !$vars{NICEVIDEO} && !$vars{DUALBOOT} && !$vars{MEDIACHECK} && !$vars{RESCUECD} && !$vars{RESCUESYSTEM} && !$vars{MEMTEST};
}

1;
# vim: set sw=4 et:
