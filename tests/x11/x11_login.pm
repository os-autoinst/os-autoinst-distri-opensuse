use base "x11test";
use testapi;

sub run() {
    my $self = shift;

    # log in
    type_string $username;
    send_key "ret";
    type_string "$password";
    send_key "ret";

    assert_screen 'generic-desktop', 20;
}

1;
# vim: set sw=4 et:
