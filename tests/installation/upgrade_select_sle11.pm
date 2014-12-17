use strict;
use base "y2logsstep";
use testapi;

sub run() {
    my $self = shift;

    # hardware detection can take a while
    assert_screen "select-for-update", 100;
    send_key $cmd{"next"}, 1;

    assert_screen 'previously-used-repositories', 5;
    send_key $cmd{"next"}, 1;

    assert_screen "update-installation-overview", 15;
}

1;
# vim: set sw=4 et:
