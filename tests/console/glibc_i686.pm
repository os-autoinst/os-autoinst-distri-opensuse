use base "consoletest";
use testapi;

# this part contains the steps to run this test
sub run() {
    my $self = shift;
    script_run("clear");
    script_sudo("zypper -n in -C libc.so.6");
    script_run("/lib/libc.so.*");
    assert_screen 'test-glibc_i686-1', 100;
}

1;
# vim: set sw=4 et:
