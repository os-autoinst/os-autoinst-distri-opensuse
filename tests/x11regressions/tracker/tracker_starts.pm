use base "x11test";
use strict;
use testapi;

sub run() {
    my $self = shift;
    x11_start_program("tracker-needle");
    sleep 2;
    wait_idle;
    assert_screen 'tracker-needle-launched';
    send_key "alt-f4";

    # assert_screen 'test-tracker_starts-2', 3;
}

1;
# vim: set sw=4 et:
