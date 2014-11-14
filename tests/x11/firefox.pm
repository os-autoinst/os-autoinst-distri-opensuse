use base "x11step";
use bmwqemu;

sub run() {
    my $self = shift;
    mouse_hide(1);
    x11_start_program("firefox", 6, { valid => 1 } );
    assert_screen 'test-firefox-1', 10;
    send_key "alt-h";
    sleep 2;    # Help
    send_key "a";
    sleep 2;    # About
    assert_screen 'test-firefox-3', 3;
    send_key "alt-f4";
    sleep 2;    # close About
    send_key "alt-f4";
    sleep 2;
    send_key "ret";    # confirm "save&quit"
}

1;
# vim: set sw=4 et:
