use base "x11test";
use testapi;

sub run() {
    my $self = shift;
    send_key "super-w";
    assert_screen 'test-awesome-menu-1', 3;
    send_key "esc";
}

1;
# vim: set sw=4 et:
