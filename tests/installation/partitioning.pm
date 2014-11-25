#!/usr/bin/perl -w
use strict;
use base "y2logsstep";
use testapi;

# Entry test code
sub run() {

    assert_screen 'partioning-edit-proposal-button', 40;

    if ( get_var("DUALBOOT") ) {
        assert_screen 'partitioning-windows', 40;
    }

}

1;
# vim: set sw=4 et:
