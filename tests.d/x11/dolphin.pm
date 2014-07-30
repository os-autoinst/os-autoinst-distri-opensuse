use base "kdestep";
use bmwqemu;

sub run() {
    my $self = shift;
    x11_start_program("dolphin");
    assert_screen 'test-dolphin-1', 3;
    send_key "alt-f4";
    sleep 2;
}

1;
# vim: set sw=4 et:
