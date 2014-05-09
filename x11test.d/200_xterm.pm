use base "basetest";
use bmwqemu;

sub is_applicable {
    return !$ENV{NICEVIDEO};
}

sub run() {
    my $self = shift;
    mouse_hide(1);
    x11_start_program("xterm");
    sleep 2;
    type_string "cd\n";
    sleep 1;             # go to $HOME (for KDE)
    send_key "ctrl-l";    # clear
    for ( 1 .. 13 ) { send_key "ret" }
    type_string "echo If you can see this text xterm is working.\n";
    sleep 2;
    assert_screen 'test-xterm-1', 3;
    send_key "alt-f4";
}

1;
# vim: set sw=4 et:
