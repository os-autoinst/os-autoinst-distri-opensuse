use base "basetest";
use bmwqemu;

sub is_applicable() {
    return $ENV{DESKTOP} eq "gnome";
}

sub run() {
    my $self = shift;
    x11_start_program("evolution");
    if ( $ENV{UPGRADE} ) { send_key "alt-f4"; waitidle; }    # close mail format change notifier
    $self->check_screen;
    sleep 1;
    send_key "ctrl-q";                                        # really quit (alt-f4 just backgrounds)
    send_key "alt-f4";
    waitidle;
}

1;
# vim: set sw=4 et:
