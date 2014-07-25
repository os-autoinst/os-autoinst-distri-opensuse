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
    assert_screen 'test-xfce_lightdm_logout_login-1', 13;
    mouse_hide();
    sendpassword;
    send_key "ret";
}

sub test_flags() {
    return { 'important' => 1 };
}

1;
# vim: set sw=4 et:
