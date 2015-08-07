use base "x11test";
use strict;
use testapi;

# Case 1436023 - Evince: Open PDF 
sub run() {
    my $self = shift;
    x11_start_program("evince " . autoinst_url . "/data/x11regressions/test.pdf");

    send_key "alt-f10";    # maximize window
    assert_screen 'evince-open-pdf', 5;
    send_key "ctrl-w";    # close evince
}

1;
# vim: set sw=4 et:
