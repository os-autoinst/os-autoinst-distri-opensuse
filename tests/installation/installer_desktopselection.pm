# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Select desktop in installer based on test settings
# Maintainer: Dominique Leuenberger <dimstar@opensuse.org>

use base 'y2_installbase';
use strict;
use warnings;
use utils 'addon_products_is_applicable';
use testapi;
use version_utils 'is_leap';

sub run {
    assert_screen 'desktop-selection';
    my $d = get_var('DESKTOP');

    # this error pop-up is present only on TW now
    if (check_var('VERSION', 'Tumbleweed')) {
        send_key $cmd{next};
        assert_screen 'desktop-not-selected';
        send_key $cmd{ok};
    }
    if (get_var('NEW_DESKTOP_SELECTION')) {
        # select computer role
        if ($d !~ /kde|gnome|textmode|serverro/) {
            $d = 'custom';
        }
    }
    if ($d !~ /kde|gnome|serverro/) {
        # up to 42.1 textmode was below 'other'
        if (!($d eq 'textmode' && check_screen 'has-server-selection', 2)) {
            send_key_until_needlematch 'selection_on_desktop_other', 'tab';    # Move the selection to 'Other'
            send_key 'spc';    # open 'Other' selection'
        }
    }
    send_key_until_needlematch "selection_on_desktop_$d", 'tab';    # Move selection to the specific desktop
    send_key 'spc';    # Select the desktop

    assert_screen "$d-selected";
    if (check_var('VERSION', 'Tumbleweed') && !get_var('OFFLINE_SUT')) {
        send_key 'alt-o';    # configure online repos
        wait_still_screen 3;    # wait for the potential 'low memory warning' to show up
        assert_screen 'repo-list';
        wait_screen_change { send_key $cmd{ok} } if match_has_tag 'repo-list-low_memory_warning';
        send_key 'alt-c';    # cancel
        send_key_until_needlematch "$d-selected", 'tab';    # select correct field to match needle
    }
    send_key $cmd{next};

    # On leap 42.3 we don't have addon products page, and provide urls as addon
    # as boot parameter. Trusting gpg key is the done after we click next
    # on Desktop selection screen
    if (addon_products_is_applicable() && is_leap('42.3+')) {
        assert_screen 'import-untrusted-gpg-key-598D0E63B3FD7E48';
        send_key "alt-t";    # confirm import (trust) key
    }

    if (get_var('NEW_DESKTOP_SELECTION') && $d eq 'custom') {
        assert_screen "pattern-selection";
        my $de = get_var('DESKTOP');
        # On the NET installer we have more than 20 patterns until walk to X
        # pattern, and pattern's ordering is an art we are not sure, therefore
        # we need to introduce a reasonable number as the counter here. On the
        # Net installer we need 77 * 'down' to the last pattern including the
        # group title, use 85 to be the counter then we have 8 spare places.
        send_key_until_needlematch "pattern-$de-selected", 'down', 86;
        send_key 'spc';
        assert_screen "pattern-$de-checked";
        send_key $cmd{ok};
    }
}

1;
