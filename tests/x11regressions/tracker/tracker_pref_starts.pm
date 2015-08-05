use base "x11test";
use strict;
use testapi;

# Case 1436344-start preference of tracker

sub run() {
    my $self = shift;
    x11_start_program("tracker-preferences");
    sleep 2;
    wait_idle;
    assert_screen 'tracker_pref_launched';
    send_key "alt-f4";
    sleep 2;

    # assert_screen 'test-tracker_pref_starts-2', 3;
}

sub checklist() {

    # return hashref:
    return {
        qw(
          )
    };
}

1;
# vim: set sw=4 et:
