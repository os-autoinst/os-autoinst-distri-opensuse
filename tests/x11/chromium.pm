use base "x11test";
use testapi;

sub run() {
    my $self = shift;

    mouse_hide;

    ensure_installed("chromium");

    x11_start_program("chromium");

    assert_screen 'chromium-main-window', 10;
    send_key "esc"; # get rid of popup
    sleep 1;
    send_key "ctrl-l";
    sleep 1;
    type_string "about:\n";
    assert_screen 'chromium-about', 15;

    send_key "ctrl-l";
    sleep 1;
    type_string "https://html5test.com/index.html\n";
    assert_screen 'chromium-html5test', 30;

    send_key "alt-f4";

    # check kwallet and cancel it
    # 1 => enable, 0 => cancel
    $self->check_kwallet(0);
}

1;
# vim: set sw=4 et:
