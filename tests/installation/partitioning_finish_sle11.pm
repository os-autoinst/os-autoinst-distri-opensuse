use strict;
use base "y2logsstep";
use testapi;

sub run() {
    assert_screen 'expert-partitioning', 5;
    send_key $cmd{"accept"};
    assert_screen 'inst-overview', 15;
}

1;
# vim: set sw=4 et:
