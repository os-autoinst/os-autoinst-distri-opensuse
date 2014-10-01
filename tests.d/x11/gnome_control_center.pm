use base "gnomestep";
use strict;
use bmwqemu;

# test gnome-control-center, with panel (boo#897687)

# this part contains the steps to run this test
sub run() {
    my $self = shift;
    mouse_hide(1);
    x11_start_program("gnome-control-center");
    type_string "details\n";
    assert_screen 'test-gnome_control_center-1', 3;
    send_key "alt-f4";
}

1;
# vim: set sw=4 et:
