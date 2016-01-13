use base "x11test";
use testapi;

sub run() {
    my $self = shift;
    send_key "super-w";
    sleep 1;
    mouse_hide(1);
    sleep 1;
    assert_screen 'test-awesome-menu-1', 3;
    send_key "esc";
}

1;
# vim: set sw=4 et:
