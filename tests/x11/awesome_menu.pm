use base "x11test";
use strict;
use testapi;
use utils;

sub run() {
    my $self = shift;
    send_key "super-w";
    assert_screen_with_soft_timeout('test-awesome-menu-1', soft_timeout => 3);
    send_key "esc";
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
