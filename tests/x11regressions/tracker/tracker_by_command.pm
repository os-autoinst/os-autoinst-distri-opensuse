use base "x11test";
use strict;
use testapi;

# Case 1436343 - Tracker: search from command line

sub run() {
    my $self = shift;
    x11_start_program("xterm");
    sleep 2;
    wait_idle;
    script_run "tracker-search newfile";
    sleep 5;
    assert_screen 'tracker-cmdsearch-newfile';
    script_run "exit";
}

1;
# vim: set sw=4 et:
