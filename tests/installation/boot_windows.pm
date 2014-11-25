use base "y2logsstep";
use testapi;

sub run() {
    my $self = shift;

    assert_screen "grub-reboot-windows", 25;

    send_key "down";
    send_key "down";
    send_key "ret";
    assert_screen "windows8", 80;
}

1;
# vim: set sw=4 et:
