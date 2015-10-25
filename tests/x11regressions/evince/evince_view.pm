use base "x11test";
use strict;
use testapi;

# Case 1436026 - Evince: View
sub run() {
    my $self = shift;
    x11_start_program("evince " . autoinst_url . "/data/x11regressions/test.pdf");

    send_key "f11";    # fullscreen mode
    assert_screen 'evince-fullscreen-mode', 5;
    send_key "esc";

    send_key "f5";     # presentation mode
    assert_screen 'evince-presentation-mode', 5;
    send_key "esc";

    send_key "ctrl-w";
}

1;
# vim: set sw=4 et:
