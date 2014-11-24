use base "xfcestep";
use strict;
use testapi;

# test xfce4-appfinder, auto-completion and starting xfce4-about

# this part contains the steps to run this test
sub run() {
    my $self = shift;
    send_key "alt-f2";
    sleep 2;
    send_key "down";
    type_string "about\n";
    assert_screen 'test-xfce4_appfinder-1', 3;
    send_key "ret", 1;
    assert_screen 'test-xfce4_appfinder-2', 3;
    send_key "alt-f4";
    sleep 2;
}

1;
# vim: set sw=4 et:
