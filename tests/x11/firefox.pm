use base "x11test";
use testapi;

sub run() {
    my $self = shift;
    wait_idle;
    mouse_hide(1);
    x11_start_program("firefox", 6, { valid => 1 } );
    assert_screen 'test-firefox-1', 60;
    if (get_var(DESKTOP) eq "kde") {
        send_key "tab";
        send_key "tab";
        send_key " ";       # uncheck Always perform default browser check, firefox audio without default browser check
        send_key "alt-y";   # accept firefox as default browser
    }
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
