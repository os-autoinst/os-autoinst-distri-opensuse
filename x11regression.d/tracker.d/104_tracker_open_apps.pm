use base "basetest";
use bmwqemu;

# Case 1248740 - Beagle: beagle-settings starts
# Modify to : Tracker: tracker-preferences starts

sub is_applicable() {
    return $ENV{DESKTOP} =~ /kde|gnome/;
}

sub run() {
    my $self = shift;
    x11_start_program("tracker-needle");
    sleep 2;
    waitidle;    # extra wait because oo sometimes appears to be idle during start
    $self->check_screen;
    sendautotype("cheese");
    sleep 2;
    waitstillimage;
    $self->check_screen;
    send_key "tab";
    sleep 2;
    send_key "down";
    sleep 2;
    send_key "ret";
    sleep 2;
    waitidle;
    $self->check_screen;
    send_key "alt-f4";
    sleep 2;    #close cheese
    send_key "alt-f4";
    sleep 2;    #close tracker

    #       $self->check_screen;
}

1;
# vim: set sw=4 et:
