use base "y2logsstep";
use strict;
use testapi;

sub run() {
    assert_screen("inst-mediacheck");
    send_key $cmd{"next"}, 1;
}

1;
