# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Installation/upgrade mode selection during installation
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base 'y2_installbase';
use testapi;

sub run {
    # autoconf phase
    # includes downloads
    assert_screen [qw(partitioning-edit-proposal-button before-role-selection inst-instmode online-repos)], 120;
    if (match_has_tag("partitioning-edit-proposal-button") || match_has_tag("before-role-selection") || match_has_tag("online-repos")) {
        # new desktop selection workflow
        set_var('NEW_DESKTOP_SELECTION', 1);
        return;
    }

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
        send_key "alt-s";    # toggle automatic configuration
        assert_screen "autoconf-deselected", 10;
    }
    send_key $cmd{next};
}

1;
