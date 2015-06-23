use strict;
use base "installbasetest";
use testapi;

sub run() {
    my $self = shift;

    $self->pass_disk_encrypt_check;
}

1;

# vim: set sw=4 et:
