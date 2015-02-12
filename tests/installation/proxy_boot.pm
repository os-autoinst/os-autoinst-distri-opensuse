use base "installbasetest";
use strict;
use testapi;

sub run() {
    assert_screen "proxy-desktop", 200;
}

1;
# vim: set sw=4 et:
