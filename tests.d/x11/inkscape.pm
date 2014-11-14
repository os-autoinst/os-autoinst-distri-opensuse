use base "x11step";
use bmwqemu;

sub is_applicable() {
    my $self = shift;
    return x11step_is_applicable && !$vars{LIVECD};
}

sub run() {
    my $self = shift;
    ensure_installed("inkscape");
    x11_start_program("inkscape");
    assert_screen 'test-inkscape-1', 3;
    send_key "alt-f4";    # Exit
}

1;
# vim: set sw=4 et:
