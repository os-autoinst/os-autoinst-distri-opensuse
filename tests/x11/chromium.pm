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
    type_string get_var("OPENQA_HOSTNAME")."\n";
    assert_screen 'chromium-openqa', 30;

    send_key "alt-f4";
}

1;
# vim: set sw=4 et:
