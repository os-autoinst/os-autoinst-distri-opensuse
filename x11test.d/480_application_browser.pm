use base "basetest";
use bmwqemu;

sub is_applicable() {
    return $ENV{DESKTOP} eq "gnome" && $ENV{GNOME2};
}

sub run() {
    my $self = shift;
    x11_start_program("application-browser");
    assert_screen 'test-application_browser-1', 3;
    send_key "alt-f4";
    waitidle;
}

1;
# vim: set sw=4 et:
