# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use strict;
use warnings;
use base "y2logsstep";
use testapi;

sub run() {
    my $self = shift;

    # autoconf phase
    # includes downloads, so wait_idle is bad.
    assert_screen "inst-instmode", 120;

    if (get_var("UPGRADE")) {
        send_key "alt-u";    # Include Add-On Products
        assert_screen "upgrade-selected";
    }

    if (get_var("HAVE_ADDON_REPOS")) {
        send_key "alt-a";    # Add online repos
    }

    if (get_var("ADDONURL") || get_var("ADDONS")) {
        # Don't include add-on from separate media for SMT upgrade bnc928895
        unless (get_var("UPGRADE") && check_var('ADDONS', 'smt')) {
            send_key "alt-c";    # Include Add-On Products
            assert_screen "addonproduct-included", 10;
        }
    }
    if (get_var("AUTOCONF")) {
        send_key "alt-s";        # toggle automatic configuration
        assert_screen "autoconf-deselected", 10;
    }
    send_key $cmd{next};
}

1;
# vim: set sw=4 et:
