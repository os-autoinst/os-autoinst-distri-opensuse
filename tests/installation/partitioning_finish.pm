use strict;
use base "y2logsstep";
use testapi;

sub run() {
    wait_still_screen();
    send_key $cmd{"next"};
    assert_screen "after-paritioning";
}

1;
# vim: set sw=4 et:
