use base "x11test";
use strict;
use testapi;

sub run() {
    my $self = shift;
    send_key "super-w";
    assert_screen 'test-awesome-menu-1', 3;
    send_key "esc";
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
