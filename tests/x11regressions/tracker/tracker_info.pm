use base "x11test";
use strict;
use testapi;

# Case 1436341 - Tracker: tracker info for file

sub run() {
    my $self = shift;
    x11_start_program("xterm");
    script_run "tracker-info newpl.pl";
    sleep 5;
    assert_screen 'tracker-info-newpl';
    send_key "alt-f4";
    sleep 2;    # close xterm
}

1;
# vim: set sw=4 et:
