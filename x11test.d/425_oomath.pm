use base "basetest";
use bmwqemu;

# test for bug https://bugs.freedesktop.org/show_bug.cgi?id=42301

sub is_applicable() {
    return 0 if $ENV{NICEVIDEO};
    return $ENV{DESKTOP} =~ /kde|gnome/ && !$ENV{LIVECD};
}

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
    $self->check_screen;
    send_key "alt-f4";
    assert_screen  'oomath-prompt', 5 ;
    send_key "alt-w";     # Without saving
}

1;
# vim: set sw=4 et:
