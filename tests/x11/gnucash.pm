# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
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
    x11_start_program('gnucash');
    send_key "ctrl-h";    # open user tutorial
    assert_screen 'test-gnucash-2';
    # Leave tutorial window
    wait_screen_change { send_key 'alt-f4' };
    # Leave tips windows for GNOME/gtk case
    if (get_var('DESKTOP', '') =~ /gnome|xfce|lxde/) {
        # LXDE specifc behaviour: After closing one window not the first
        # opened gets focussed but the last. Bring the tip window back to
        # focus if it is not
        send_key 'alt-tab' if check_var('DESKTOP', 'lxde');
        wait_screen_change { send_key 'alt-c' };
    }
    # sometimes send_key for closing windows not working
    send_key_until_needlematch 'gnucash-save-changes', "ctrl-q", 5, 5;
    wait_screen_change { send_key 'alt-w' };
}

1;
