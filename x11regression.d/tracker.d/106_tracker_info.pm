use base "basetest";
use bmwqemu;

# Case 1248741 - Beagle: beagle text filter extracts content
# Modify to : Tracker - tracker info for files

sub is_applicable() {
    return $ENV{DESKTOP} =~ /kde|gnome/;
}

sub run() {
    my $self = shift;
    x11_start_program("xterm");
    sleep 2;
    waitidle;
    assert_screen 'test-tracker_info-1', 3;
    type_string "cd\n";
    type_string "tracker-info newpl.pl\n";
    sleep 2;
    waitstillimage;
    assert_screen 'test-tracker_info-2', 3;
    send_key "alt-f4";
    sleep 2;    # close xterm
                # assert_screen 'test-tracker_info-3', 3;
}

1;
# vim: set sw=4 et:
