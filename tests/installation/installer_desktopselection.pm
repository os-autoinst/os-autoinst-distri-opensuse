# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Select desktop in installer based on test settings
# Maintainer: Dominique Leuenberger <dimstar@opensuse.org>

use strict;
use base "y2logsstep";
use testapi;

sub run() {
    my $install_patterns = '';
    assert_screen 'desktop-selection';
    my $d = get_var('DESKTOP');

    if (get_var('NEW_DESKTOP_SELECTION')) {
        # select computer role
        if ($d ne 'kde' && $d ne 'gnome' && $d ne 'textmode') {
            $d = 'custom';
        }
        if ($d eq 'custom') {
            $install_patterns = 'x11' if get_var('DESKTOP') eq 'minimalx';
        }
    }
    if ($d ne 'kde' && $d ne 'gnome') {
        # up to 42.1 textmode was below 'other'
        if (!($d eq 'textmode' && check_screen 'has-server-selection', 2)) {
            send_key_until_needlematch 'selection_on_desktop_other', 'tab';    # Move the selection to 'Other'
            send_key 'spc';                                                    # open 'Other' selection'
        }
    }
    # somehow 'tabbing' through selections does not work in the live
    # installer but we know we are in graphical environment so we can get
    # away with just asserting the right selection and continuing
    if (!get_var('LIVECD')) {
        send_key_until_needlematch "selection_on_desktop_$d", 'tab';    # Move selection to the specific desktop
        send_key 'spc';                                                 # Select the desktop
    }
    assert_screen "$d-selected";
    send_key $cmd{next};

    if (get_var('NEW_DESKTOP_SELECTION') && $d eq 'custom') {
        assert_screen "pattern-selection";
        for my $p (split(/,/, $install_patterns)) {
            assert_and_click "pattern-$p";
            assert_and_click "pattern-$p-selected";
        }
        send_key $cmd{ok};
    }
}

1;
# vim: set sw=4 et:
