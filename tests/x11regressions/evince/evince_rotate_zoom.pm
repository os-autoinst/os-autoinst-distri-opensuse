use base "x11test";
use strict;
use testapi;

# Case 1436024 - Evince: Rotate and Zoom
sub run() {
    my $self = shift;
    x11_start_program("evince " . autoinst_url . "/data/x11regressions/test.pdf");

    send_key "ctrl-left";    # rotate left
    assert_screen 'evince-rotate-left', 5;
    send_key "ctrl-right";
    send_key "ctrl-right";    # rotate right
    assert_screen 'evince-rotate-right', 5;
    send_key "ctrl-left";

    send_key "ctrl-+";    # zoom in
    assert_screen 'evince-zoom-in', 5;

    for (1 .. 2) {
        send_key "ctrl-minus";    # zoom out
    }
    assert_screen 'evince-zoom-out', 5;
    send_key "ctrl-+";

    send_key "ctrl-w";
}

1;
# vim: set sw=4 et:
