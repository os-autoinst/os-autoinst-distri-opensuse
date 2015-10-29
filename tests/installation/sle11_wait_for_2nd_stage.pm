use base "y2logsstep";
use strict;
use testapi;
use utils;

sub run() {
    unlock_if_encrypted;
    assert_screen "second-stage", 250;
    mouse_hide;
    sleep 1;
    mouse_hide;
}

1;

# vim: sw=4 et
