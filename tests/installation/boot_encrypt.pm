use strict;
use base "installbasetest";
use utils;

sub run() {
    unlock_if_encrypted;
}

sub post_fail_hook() {
    my $self = shift;

    $self->export_logs();
}

1;

# vim: set sw=4 et:
