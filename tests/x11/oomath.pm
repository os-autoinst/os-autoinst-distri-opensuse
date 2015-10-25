use base "x11test";
use testapi;

# test for bug https://bugs.freedesktop.org/show_bug.cgi?id=42301

sub run() {
    my $self = shift;
    x11_start_program("oomath");
    type_string "E %PHI = H %PHI\nnewline\n1 = 1";
    sleep 3;

    # test broken undo
    send_key "shift-left";
    send_key "2";
    send_key "ctrl-z";    # undo produces "12" instead of "1"
    sleep 3;
    assert_screen 'test-oomath-1', 3;
    send_key "alt-f4";
    assert_screen 'oomath-prompt', 5;
    assert_and_click 'dont-save-libreoffice-btn';    # _Don't save
}

1;
# vim: set sw=4 et:
