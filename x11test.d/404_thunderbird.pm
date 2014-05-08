use base "basetest";
use bmwqemu;

sub is_applicable() {
    return $ENV{DESKTOP} eq "gnome" && !$ENV{LIVECD};
}

sub run() {
    my $self = shift;
    ensure_installed("thunderbird");
    x11_start_program("thunderbird");
    $self->check_screen;
    send_key "alt-f4", 1;    # close wizzard
    send_key "alt-f4", 1;    # close prog
}

1;
# vim: set sw=4 et:
