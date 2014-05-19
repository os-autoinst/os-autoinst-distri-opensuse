use base "basetest";
use strict;
use bmwqemu;

# install tomboy

# this function decides if the test shall run
sub is_applicable {
    return ( $vars{DESKTOP} eq "gnome" );
}

# this part contains the steps to run this test
sub run() {
    my $self = shift;
    mouse_hide();
    sleep 60;
    wait_idle;
    ensure_installed("tomboy");
    send_key "ret";
    sleep 90;
    send_key "esc";
    sleep 5;
    wait_idle;

    #save_screenshot;
}

1;
# vim: set sw=4 et:
