package installzdupstep;
use base "installbasetest";

use bmwqemu;

sub is_applicable() {
    my $self = shift;
    return $self->SUPER::is_applicable && !$vars{NOINSTALL} && !$vars{LIVETEST} && !$vars{MEDIACHECK} && !$vars{MEMTEST} && $vars{ZDUP};
}

1;
# vim: set sw=4 et:
