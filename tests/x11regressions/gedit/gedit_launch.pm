use base "x11test";
use strict;
use testapi;

# Case 1436122 - Gedit: Start and exit
sub run() {
    my $self = shift;
    x11_start_program("gedit");
    assert_screen 'gedit-launched', 3;
    assert_and_click 'gedit-x-button';

    x11_start_program("gedit");
    assert_screen 'gedit-launched', 3;
    send_key "ctrl-q";
}

1;
# vim: set sw=4 et:
