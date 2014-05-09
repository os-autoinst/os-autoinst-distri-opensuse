use base "basetest";
use strict;
use bmwqemu;

# test xfce4-notifyd with a notification

# this function decides if the test shall run
sub is_applicable {
    return ( $ENV{DESKTOP} eq "xfce" );
}

# this part contains the steps to run this test
sub run() {
    my $self = shift;
    x11_start_program('notify-send --expire-time=10 Test');
    sleep 2;
    assert_screen 'test-xfce_notification-1', 3;
    sleep 10;
}

1;
# vim: set sw=4 et:
