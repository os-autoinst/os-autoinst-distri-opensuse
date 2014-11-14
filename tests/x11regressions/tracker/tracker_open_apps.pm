use base "basetest";
use bmwqemu;

# Case 1248740 - Beagle: beagle-settings starts
# Modify to : Tracker: tracker-preferences starts

sub run() {
    my $self = shift;
    x11_start_program("tracker-needle");
    sleep 2;
    wait_idle;    # extra wait because oo sometimes appears to be idle during start
    assert_screen 'test-tracker_open_apps-1', 3;
    type_string "cheese";
    sleep 2;
    waitstillimage;
    assert_screen 'test-tracker_open_apps-2', 3;
    send_key "tab";
    sleep 2;
    send_key "down";
    sleep 2;
    send_key "ret";
    sleep 2;
    wait_idle;
    assert_screen 'test-tracker_open_apps-3', 3;
    send_key "alt-f4";
    sleep 2;    #close cheese
    send_key "alt-f4";
    sleep 2;    #close tracker

    #       assert_screen 'test-tracker_open_apps-4', 3;
}

1;
# vim: set sw=4 et:
