use base "xfcestep";
use strict;
use bmwqemu;

sub is_applicable {
    my $self = shift;
    return xfcestep_is_applicable && !( $vars{FLAVOR} eq 'Rescue-CD' );
}

# log out, check lightdm-gtk-greeter and log in again

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
