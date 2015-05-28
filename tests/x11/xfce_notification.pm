use base "x11test";
use strict;
use testapi;

# test xfce4-notifyd with a notification

# this part contains the steps to run this test
sub run() {
    my $self = shift;
    x11_start_program('notify-send --expire-time=30 Test');
    assert_screen 'test-xfce_notification-1', 5;
}

1;
# vim: set sw=4 et:
