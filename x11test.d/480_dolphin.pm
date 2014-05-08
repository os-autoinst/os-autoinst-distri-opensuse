use base "basetest";
use bmwqemu;

sub is_applicable() {
    return $ENV{DESKTOP} eq "kde";
}

sub run() {
    my $self = shift;
    x11_start_program("dolphin");
    $self->check_screen;
    send_key "alt-f4";
    sleep 2;
}

1;
# vim: set sw=4 et:
