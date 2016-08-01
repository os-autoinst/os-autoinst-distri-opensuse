# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Case#1479413: Firefox: Full Screen Browsing

use strict;
use base "x11regressiontest";
use testapi;

sub run() {
    mouse_hide(1);

    # Clean and Start Firefox
    x11_start_program("xterm -e \"killall -9 firefox;rm -rf .moz*\"");
    x11_start_program("firefox");
    assert_screen('firefox-launch', 90);

    send_key "esc";
    sleep 1;
    send_key "alt-d";
    sleep 1;
    type_string "file:///usr/share/w3m/w3mhelp.html\n";
    assert_screen('firefox-fullscreen-page', 15);

    send_key "f11";
    assert_screen('firefox-fullscreen-enter', 15);

    sleep 1;
    send_key "f11";
    assert_screen('firefox-fullscreen-page', 15);

    # Exit
    send_key "alt-f4";

    if (check_screen('firefox-save-and-quit', 4)) {
        # confirm "save&quit"
        send_key "ret";
    }
}
1;
# vim: set sw=4 et:
