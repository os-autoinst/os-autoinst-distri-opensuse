use base "basetest";
use bmwqemu;

# Clean for testing tracker.

my @filenames = qw/newfile newpl.pl/;

sub is_applicable() {
    return $ENV{DESKTOP} =~ /kde|gnome/;
}

sub run() {
    my $self = shift;

    # Delete a file.
    foreach (@filenames) {
        x11_start_program("rm -rf $_");
        sleep 2;
    }
    wait_idle;
}

1;
# vim: set sw=4 et:
