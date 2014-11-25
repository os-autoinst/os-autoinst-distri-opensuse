use strict;
use base "y2logsstep";
use testapi;

sub run() {
    my $self = shift;

    assert_screen("encrypted-disk-password-prompt");
    type_password();    # enter PW at boot
    send_key "ret";
}

1;

# vim: set sw=4 et:
