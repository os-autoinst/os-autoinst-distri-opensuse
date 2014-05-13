use base "basetest";
use bmwqemu;

# Case 1248746 - Beagle: Find a file with Search in Nautilus
# Modify to : Tracker - Find a file with Search in Nautilus

sub is_applicable() {
    return $vars{DESKTOP} =~ /kde|gnome/;
}

sub run() {
    my $self = shift;
    x11_start_program("nautilus");
    sleep 2;
    wait_idle;
    assert_screen 'test-tracker_search_in_nautilus-1', 3;
    send_key "ctrl-f";
    sleep 2;
    type_string "newfile";
    send_key "ret";
    sleep 2;
    wait_idle;
    assert_screen 'test-tracker_search_in_nautilus-2', 3;  # should open file newfile
    type_string "Hello world.\n";
    sleep 2;
    send_key "ctrl-s";
    sleep 2;
    waitstillimage;
    assert_screen 'test-tracker_search_in_nautilus-3', 3;
    send_key "alt-f4";
    sleep 2;                #close gedit
    assert_screen 'test-tracker_search_in_nautilus-4', 3;
    send_key "alt-f4";
    sleep 2;                #close nautilus
}

1;
# vim: set sw=4 et:
