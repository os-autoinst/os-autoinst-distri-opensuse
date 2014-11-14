use base "basetest";
use bmwqemu;

# Preparation for testing tracker.

# Used for 106_tracker_info
my @filenames = qw/newfile newpl.pl/;

sub run() {
    my $self = shift;

    # Create a file.
    foreach (@filenames) {
        x11_start_program("touch $_");
        sleep 2;
    }
    wait_idle;
}

1;
# vim: set sw=4 et:
