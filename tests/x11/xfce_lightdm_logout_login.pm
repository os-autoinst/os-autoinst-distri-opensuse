use base "x11test";
use strict;
use testapi;

# log out, check lightdm-gtk-greeter and log in again

# this part contains the steps to run this test
sub run() {
    my $self = shift;
    x11_start_program("xfce4-session-logout");
    send_key "alt-l";
    assert_screen 'test-xfce_lightdm_logout_login-1', 13;
    mouse_hide();
    type_password;
    send_key "ret";
}

sub test_flags() {
    return { important => 1 };
}

1;
# vim: set sw=4 et:
