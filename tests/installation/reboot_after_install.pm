use base "installbasetest";
use testapi;

sub run() {
    my $self = shift;

    assert_screen "reboot_after_install", 200;
}

1;
# vim: set sw=4 et:
