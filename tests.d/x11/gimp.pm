use base "x11step";
use bmwqemu;

# XXX TODO - is using KDE variable here
sub is_applicable() {
    my $self = shift;
    return $self->SUPER::is_applicable && !$vars{NICEVIDEO} && !$vars{LIVECD};
}

sub run() {
    my $self = shift;
    ensure_installed("gimp");
    x11_start_program("gimp");
    assert_screen "test-gimp-1", 20;
    send_key "alt-f4";    # Exit
}

1;
# vim: set sw=4 et:
