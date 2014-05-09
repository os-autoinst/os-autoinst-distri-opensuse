use base "basetest";
use bmwqemu;

# this part contains the steps to run this test
sub run() {
    my $self = shift;
    script_run("clear");
    script_run("/lib/libc.so.*");
    assert_screen 'test-glib_i686-1', 3;
}

1;
# vim: set sw=4 et:
