use base "y2logsstep";
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
    assert_screen 'dasd-unselected';
    send_key 'alt-s';
    assert_screen 'dasd-selected';
    send_key 'alt-a';
    assert_screen 'action-list';
    send_key 'a';
    assert_screen 'dasd-active';
    send_key 'alt-n';
    assert_screen 'disk-activation', 15;
    send_key 'alt-n';
}

1;
# vim: set sw=4 et:
