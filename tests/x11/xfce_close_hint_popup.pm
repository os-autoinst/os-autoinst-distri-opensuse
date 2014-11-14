use base "xfcestep";
use bmwqemu;

sub run() {
    my $self = shift;
    assert_screen "XFCE", 30;
    send_key "alt-c";    # close hint popup
    wait_idle;
}

1;
# vim: set sw=4 et:
