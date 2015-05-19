#!/usr/bin/perl -w
use strict;
use base "y2logsstep";
use testapi;

sub run() {
    my $self = shift;

    # autoconf phase
    # includes downloads, so wait_idle is bad.
    assert_screen "inst-instmode", 120;

    if ( get_var("UPGRADE") ) {
        send_key "alt-u";    # Include Add-On Products
        assert_screen "upgrade-selected", 2;
    }

    if ( get_var("ADDONURL") || get_var("ADDONS") ) {
        if (!check_var('ADDONS', 'smt')) {  # no include for SMT add-on bnc928895
            send_key "alt-c";    # Include Add-On Products
            assert_screen "addonproduct-included", 10;
        }
    }
    if ( get_var("AUTOCONF") ) {
        send_key "alt-s";    # toggle automatic configuration
        assert_screen "autoconf-deselected", 10;
    }
    send_key $cmd{"next"}, 1;
}

1;
# vim: set sw=4 et:
