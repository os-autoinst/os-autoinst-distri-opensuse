# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Case#1479188: Firefox: Add-ons - Plugins

use strict;
use base "x11test";
use testapi;

sub run() {
    mouse_hide(1);

    # Clean and Start Firefox
    x11_start_program("xterm -e \"killall -9 firefox;rm -rf .moz*\"");
    x11_start_program("firefox");
    assert_screen('firefox-launch', 90);

    send_key "ctrl-shift-a";
    assert_and_click('firefox-addons-plugins');
    assert_screen('firefox-plugins-overview_01', 10);

    for my $i (1 .. 2) { send_key "tab"; }
    send_key "pgdn";
    assert_screen('firefox-plugins-overview_02', 10);

    assert_and_click('firefox-plugins-check_update');
    assert_screen('firefox-plugins-update_page', 35);

    # Exit
    send_key "alt-f4";

    if (check_screen('firefox-save-and-quit', 4)) {
        # confirm "save&quit"
        send_key "ret";
    }
}
1;
# vim: set sw=4 et:
