use base "basetest";
use bmwqemu;

sub is_applicable() {
    return $ENV{DESKTOP} =~ /kde|gnome/;
}

sub run() {
    my $self = shift;
    x11_start_program("oowriter");
    sleep 2;
    waitidle;    # extra wait because oo sometimes appears to be idle during start
    $self->check_screen;
    sendautotype("Hello World!");
    sleep 2;
    $self->check_screen;
    send_key "alt-f4";
    sleep 2;
    waitforneedle( "ooffice-save-prompt", 8 );
    send_key "alt-w";
    sleep 2;     # *W*ithout saving
}

1;
# vim: set sw=4 et:
