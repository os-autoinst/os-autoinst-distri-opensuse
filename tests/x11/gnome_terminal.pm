use base "opensusebasetest";
use strict;
use testapi;

# test gnome-terminal

# this part contains the steps to run this test
sub run() {
    my $self = shift;
    mouse_hide(1);
    x11_start_program("gnome-terminal");
    sleep 2;
    send_key "ctrl-shift-t";
    for ( 1 .. 13 ) { send_key "ret" }
    type_string "echo If you can see this text gnome-terminal is working.\n";
    sleep 2;
    assert_screen 'test-gnome_terminal-1', 3;
    sleep 2;
    send_key "alt-f4";
    sleep 2;
}

1;
# vim: set sw=4 et:
