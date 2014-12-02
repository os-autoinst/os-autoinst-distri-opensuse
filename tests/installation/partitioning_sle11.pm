#!/usr/bin/perl -w
use strict;
use base "y2logsstep";
use testapi;

# Entry test code
sub run() {

    assert_screen 'installation-overview', 40;
    send_key $cmd{change};
    send_key 'p'; # paritioning

}

1;
# vim: set sw=4 et:
