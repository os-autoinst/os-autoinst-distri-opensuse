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
use warnings;
use testapi;
use version_utils 'is_leap';

sub run {
    select_console('x11');

    ensure_installed('gnucash gnucash-docs yelp');
    x11_start_program('gnucash', target_match => [qw(gnucash gnucash-tip-close gnucash-assistant-close)]);
    if (match_has_tag('gnucash-tip-close')) {
        assert_and_click 'gnucash-tip-close';
        assert_screen([qw(gnucash gnucash-assistant-close)]);
    }
    if (match_has_tag('gnucash-assistant-close')) {
        assert_and_click 'gnucash-assistant-close';
        assert_and_click 'gnucash-assistant-show-again-no';
        assert_screen('gnucash');
    }
    # < gnucash 3.3
    else {
        send_key "ctrl-h";    # open user tutorial
        assert_screen 'test-gnucash-2';
        # Leave tutorial window
        send_key 'alt-f4';
        assert_screen('gnucash');
        # Leave tips windows for GNOME/gtk case
        if (get_var('DESKTOP', '') =~ /gnome|xfce|lxde/) {
            # LXDE specifc behaviour: After closing one window not the first
            # opened gets focussed but the last. Bring the tip window back to
            # focus if it is not
            send_key 'alt-tab' if check_var('DESKTOP', 'lxde');
            send_key 'alt-c';
            assert_screen('test-gnucash-tips-closed');
        }
    }
    assert_and_click('gnucash-close-window');
    assert_screen([qw(generic-desktop gnucash-close-without-saving-changes)]);
    assert_and_click('gnucash-close-without-saving-changes') if match_has_tag('gnucash-close-without-saving-changes');
}

1;
