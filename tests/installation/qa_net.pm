use base "installbasetest";
use strict;
use testapi;
use Time::HiRes qw(sleep);

use bmwqemu ();

sub run() {
    my ($self) = @_;

    assert_screen "qa-net-selection", 300;
    $bmwqemu::backend->relogin_vnc();

    $self->key_round("qa-net-selection-" . get_var('DISTRI') . "-" . get_var("VERSION"), 'down', 30, 3);
    send_key 'ret';
    $self->key_round("qa-net-nfs", 'down', 30, 3);
    send_key 'ret';
    $self->key_round("qa-net-x11", 'down', 30, 3);
    send_key 'ret';
}

1;

# vim: set sw=4 et:
