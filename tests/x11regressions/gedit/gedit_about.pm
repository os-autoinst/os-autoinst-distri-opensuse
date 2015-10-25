use base "x11test";
use strict;
use testapi;

# Case 1436120 - Gedit: help about
sub run() {
    my $self = shift;
    x11_start_program("gedit");

    # check about window
    send_key "alt-h", 1;
    send_key "a";
    assert_screen 'gedit-help-about', 3;

    # check license
    assert_screen 'gedit-about-license', 3;

    # check website link
    assert_and_click 'gedit-about-link';
    # give a little time to open and load website
    assert_screen 'gedit-open-firefox', 60;
    send_key "ctrl-q",                  1;

    # check credits
    send_key "alt-r";
    assert_screen 'gedit-about-credits', 3;
    send_key "alt-r";    # close credit

    send_key "alt-c", 1; # close about
    send_key "ctrl-q";
}

1;
# vim: set sw=4 et:
