use strict;
use base "y2logsstep";
use testapi;

sub run() {
    my $self = shift;

    # Eject the DVD
    send_key "ctrl-alt-f3";
    assert_screen('text-login');
    send_key "ctrl-alt-delete";

    # Bug in 13.1?
    power('reset');

    # eject_cd;

    if (get_var("ENCRYPT")) {
        $self->pass_disk_encrypt_check;
    }
}

1;

# vim: set sw=4 et:
