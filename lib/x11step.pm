package x11step;
use base "opensusebasetest";
use bmwqemu;

# Base class for all X11 tests

sub is_applicable() {
    my $self = shift;
    return $self->SUPER::is_applicable && !$vars{INSTALLONLY} && $vars{DESKTOP} !~ /textmode|minimalx/ && !$vars{DUALBOOT} && !$vars{MEDIACHECK} && !$vars{MEMTEST} && !$vars{RESCUECD};
}

1;
# vim: set sw=4 et:
