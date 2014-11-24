use base "gnomestep";
use testapi;

sub run() {
    my $self = shift;
    x11_start_program("nautilus");
    assert_screen 'test-nautilus-1', 3;
    send_key "alt-f4";
    sleep 2;
}

1;
# vim: set sw=4 et:
