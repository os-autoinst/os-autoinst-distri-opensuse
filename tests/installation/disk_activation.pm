use base "y2logstep";
use strict;
use testapi;

sub run {
    my $self = shift;

    assert_screen 'disk-activation', 15;
    send_key 'alt-d';
    assert_screen 'dasd-disk-management';
    send_key 'alt-m';
    type_string '0.0.0150';
    send_key 'alt-x';
    type_string '0.0.0150';
    send_key 'alt-f';
    send_key 'alt-s';
    assert_screen 'dasd-selected';
    send_key 'alt-a';
    send_key 'alt-a';
    send_key 'alt-n';
    assert_screen 'disk-activation', 15;
    send_key 'alt-n';
}

1;
# vim: set sw=4 et:
