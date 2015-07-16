use base "x11test";
use testapi;

sub run() {
    my $self = shift;
    x11_start_program("rhythmbox");
    assert_screen 'test-rhythmbox-1', 15;
    send_key "alt-f4";
    wait_idle;
}

1;
# vim: set sw=4 et:
