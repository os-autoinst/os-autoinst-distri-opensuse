use base "basetest";
use bmwqemu;

sub is_applicable() {
    return 0 if $ENV{NICEVIDEO};
    return !( $ENV{KDE} && $ENV{LIVECD} );
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
