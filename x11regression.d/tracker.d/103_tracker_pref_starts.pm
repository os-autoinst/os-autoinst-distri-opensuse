use base "basetest";
use bmwqemu;

# Case 1248740 - Beagle: beagle-settings starts
# Modify to : Tracker: tracker-preferences starts

sub is_applicable() {
    return $envs->{DESKTOP} =~ /kde|gnome/;
}

sub run() {
    my $self = shift;
    x11_start_program("tracker-preferences");
    sleep 2;
    waitidle;
    assert_screen 'test-tracker_pref_starts-1', 3;
    send_key "alt-f4";
    sleep 2;

    # assert_screen 'test-tracker_pref_starts-2', 3;
}

sub checklist() {

    # return hashref:
    return {
        qw(
          )
    };
}

1;
# vim: set sw=4 et:
