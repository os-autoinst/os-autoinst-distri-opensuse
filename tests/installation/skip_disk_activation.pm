use base "y2logsstep";
use strict;
use testapi;

sub run {
    my $self = shift;

    # we should not have it
    record_soft_failure;
    sleep 3;
    send_key 'alt-n';    # next
    sleep 5;
}

1;
# vim: set sw=4 et:
