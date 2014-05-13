use base "basetest";
use bmwqemu;

# Case 1248747 - Beagle: beagled starts
# Modify to : Tracker - tracker search from the command line. tracker-search starts

sub is_applicable() {
    return $vars{DESKTOP} =~ /kde|gnome/;
}

sub run() {
    my $self = shift;
    x11_start_program("xterm");
    sleep 2;
    wait_idle;
    assert_screen 'test-tracker_by_command-1', 3;
    type_string "cd\n";
    type_string "tracker-search newfile\n";
    sleep 2;
    waitstillimage;
    assert_screen 'test-tracker_by_command-2', 3;
    send_key "alt-f4";
    sleep 2;    #close xterm

    #       assert_screen 'test-tracker_by_command-3', 3;
}

1;
# vim: set sw=4 et:
