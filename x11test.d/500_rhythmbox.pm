use base "basetest";
use bmwqemu;

sub is_applicable() {
    return $ENV{DESKTOP} eq "gnome" && !$ENV{LIVECD};
}

sub run() {
    my $self = shift;
    x11_start_program("rhythmbox");
    $self->check_screen;
    send_key "alt-f4";
    waitidle;
}

1;
# vim: set sw=4 et:
