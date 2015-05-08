package firefox;
use base "x11test";
use testapi;

sub start_firefox() {
    x11_start_program("firefox https://html5test.com/index.html", 6, { valid => 1 } );
    assert_screen 'test-firefox-1', 35;
}

sub run() {
    my $self = shift;
    mouse_hide(1);
    $self->start_firefox();
    send_key "alt-h";
    assert_screen 'firefox-help-menu', 3;
    send_key "a";
    assert_screen 'test-firefox-3', 10;

    # close About
    send_key "alt-f4";
    assert_screen 'test-firefox-1', 3;

    send_key "alt-f4";
    if (check_screen('firefox-save-and-quit', 4)) {
       # confirm "save&quit"
       send_key "ret";
    }
}

1;
# vim: set sw=4 et:
