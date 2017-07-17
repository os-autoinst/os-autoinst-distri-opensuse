# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Gnucash startup
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "x11test";
use strict;
use testapi;

sub run {
    ensure_installed("gnucash");
    ensure_installed("gnucash-docs");

    # needed for viewing
    ensure_installed("yelp");
    x11_start_program("gnucash");
    assert_screen 'test-gnucash-1';
    send_key "ctrl-h";    # open user tutorial
    assert_screen 'test-gnucash-2';
    # Leave tutorial window
    wait_screen_change { send_key 'alt-f4' };
    # Leave tips windows for GNOME case
    if (check_var('DESKTOP', 'gnome') || check_var('DESKTOP', 'xfce')) {
        wait_screen_change { send_key 'alt-c' };
    }
    send_key 'ctrl-q';    # Exit
    assert_screen [qw(gnucash-save-changes generic-desktop)];
    wait_screen_change { send_key 'alt-w' } if match_has_tag 'gnucash-save-changes';
}

1;
# vim: set sw=4 et:
