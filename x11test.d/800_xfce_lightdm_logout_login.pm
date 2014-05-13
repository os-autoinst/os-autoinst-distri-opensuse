use base "basetest";
use strict;
use bmwqemu;

# log out, check lightdm-gtk-greeter and log in again

# this function decides if the test shall run
sub is_applicable {
    return ( $vars{DESKTOP} eq "xfce" );
}

# this part contains the steps to run this test
sub run() {
    my $self = shift;
    x11_start_program("xfce4-session-logout");
    send_key "alt-l";
    sleep 10;
    assert_screen 'test-xfce_lightdm_logout_login-1', 3;
    sendpassword;
    send_key "ret";
    sleep 10;
}

1;
# vim: set sw=4 et:
