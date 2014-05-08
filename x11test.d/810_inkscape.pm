use base "basetest";
use bmwqemu;

sub is_applicable() {
    return !$ENV{LIVECD};
}

sub run() {
    my $self = shift;
    ensure_installed("inkscape");
    x11_start_program("inkscape");
    $self->check_screen;
    send_key "alt-f4";    # Exit
}

1;
# vim: set sw=4 et:
