use base "basetest";
use strict;
use testapi;


sub run() {
    my $self = shift;
    ensure_installed("virt-manager");
    wait_idle;
}

1;
# vim: set sw=4 et:

