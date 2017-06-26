# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
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
        if ($d ne 'kde' && $d ne 'gnome' && $d ne 'textmode') {
            $d = 'custom';
        }
    }
    if ($d ne 'kde' && $d ne 'gnome') {
        # up to 42.1 textmode was below 'other'
        if (!($d eq 'textmode' && check_screen 'has-server-selection', 2)) {
            send_key_until_needlematch 'selection_on_desktop_other', 'tab';    # Move the selection to 'Other'
            send_key 'spc';                                                    # open 'Other' selection'
        }
    }
    send_key_until_needlematch "selection_on_desktop_$d", 'tab';               # Move selection to the specific desktop
    send_key 'spc';                                                            # Select the desktop

    assert_screen "$d-selected";
    if (check_var('VERSION', 'Tumbleweed')) {
        send_key 'alt-o';                                                      # configure online repos
        wait_still_screen 3;                                                   # wait for the potential 'low memory warning' to show up
        assert_screen 'repo-list';
        wait_screen_change { send_key $cmd{ok} } if match_has_tag 'repo-list-low_memory_warning';
        send_key 'alt-c';                                                      # cancel
        send_key_until_needlematch "$d-selected", 'tab';                       # select correct field to match needle
    }
    send_key $cmd{next};

    if (get_var('NEW_DESKTOP_SELECTION') && $d eq 'custom') {
        assert_screen "pattern-selection";
        my $de = get_var('DESKTOP');
        # On the NET installer we have more than 20 patterns until walk to X
        # pattern, and pattern's ordering is an art we are not sure, therefore
        # we need to introduce a reasonable number as the counter here. On the
        # Net installer we need 77 * 'down' to the last pattern including the
        # group title, use 85 to be the counter then we have 8 spare places.
        send_key_until_needlematch "pattern-$de-selected", 'down', 85;
        send_key 'spc';
        assert_screen "pattern-$de-checked";
        send_key $cmd{ok};
    }
}

1;
# vim: set sw=4 et:
