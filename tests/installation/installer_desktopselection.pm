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
    assert_screen 'desktop-selection';
    my $d = get_var('DESKTOP');

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
    send_key $cmd{next};

    if (get_var('NEW_DESKTOP_SELECTION') && $d eq 'custom') {
        assert_screen "pattern-selection";
        my $de = get_var('DESKTOP');
        send_key_until_needlematch "pattern-$de-selected", 'down';
        send_key 'spc';
        assert_screen "pattern-$de-checked";
        send_key $cmd{ok};
    }
}

1;
# vim: set sw=4 et:
