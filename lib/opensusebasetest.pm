package opensusebasetest;
use base "basetest";

# Base class for all openSUSE tests

sub opensusebasetest_is_applicable() {
    return 1;
}

sub x11step_is_applicable() {
    return !$vars{INSTALLONLY} && $vars{DESKTOP} !~ /textmode|minimalx/ && !$vars{DUALBOOT} && !$vars{MEDIACHECK} && !$vars{MEMTEST} && !$vars{RESCUECD} && !$vars{RESCUESYSTEM};
}

sub xfcestep_is_applicable() {
    return x11step_is_applicable && ( $vars{DESKTOP} eq "xfce" );
}

sub rescuecdstep_is_applicable() {
    return $vars{RESCUECD};
}

sub consolestep_is_applicable() {
    return !$vars{INSTALLONLY} && !$vars{NICEVIDEO} && !$vars{DUALBOOT} && !$vars{MEDIACHECK} && !$vars{RESCUECD} && !$vars{RESCUESYSTEM} && !$vars{MEMTEST};
}

sub kdestep_is_applicable() {
    return x11step_is_applicable && ( $vars{DESKTOP} eq "kde" );
}

sub installzdupstep_is_applicable() {
    return installbasetest_is_applicable && !$vars{NOINSTALL} && !$vars{LIVETEST} && !$vars{MEDIACHECK} && !$vars{MEMTEST} && !$vars{RESCUECD} && !$vars{RESCUESYSTEM} && $vars{ZDUP};
}

sub noupdatestep_is_applicable() {
    return y2logsstep_is_applicable && !$vars{UPGRADE};
}

sub bigx11step_is_applicable() {
    return x11step_is_applicable && $vars{BIGTEST};
}

sub bigconsolestep_is_applicable() {
    return consolestep_is_applicable && $vars{BIGTEST};
}

sub installyaststep_is_applicable() {
    return installbasetest_is_applicable && !$vars{NOINSTALL} && !$vars{LIVETEST} && !$vars{MEDIACHECK} && !$vars{MEMTEST} && !$vars{RESCUECD} && !$vars{RESCUESYSTEM} && !$vars{ZDUP};
}

sub gnomestep_is_applicable() {
    return x11step_is_applicable && ( $vars{DESKTOP} eq "gnome" );
}

sub serverstep_is_applicable() {
    return consolestep_is_applicable && !$bmwqemu::vars{NOINSTALL} && !$bmwqemu::vars{LIVETEST} && ( $bmwqemu::vars{DESKTOP} eq "textmode" );
}

sub is_applicable() {
    return opensusebasetest_is_applicable;
}

1;
# vim: set sw=4 et:
