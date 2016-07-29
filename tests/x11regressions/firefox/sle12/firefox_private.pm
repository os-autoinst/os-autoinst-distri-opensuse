# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Case#1479412: Firefox: Private Browsing

use strict;
use base "x11test";
use testapi;

sub run() {
    mouse_hide(1);

    # Clean and Start Firefox
    x11_start_program("xterm -e \"killall -9 firefox;rm -rf .moz*\"");
    x11_start_program("firefox");
    assert_screen('firefox-launch', 90);

    send_key "ctrl-shift-p";
    sleep 5;

    send_key "alt-d";
    type_string "gnu.org\n";
    assert_screen('firefox-private-gnu', 45);
    send_key "alt-d";
    type_string "facebook.com\n";
    assert_screen('firefox-private-facebook', 45);

    sleep 1;
    send_key "alt-f4";
    sleep 1;
    send_key "alt-f4";

    sleep 2;
    x11_start_program("firefox");
    assert_screen('firefox-launch', 30);

    send_key "ctrl-h";
    assert_and_click('firefox-private-checktoday');
    assert_screen('firefox-private-checkhistory', 10);

    sleep 1;
    send_key "alt-f4";

    # Exit
    send_key "alt-f4";

    if (check_screen('firefox-save-and-quit', 4)) {
        # confirm "save&quit"
        send_key "ret";
    }
}
1;
# vim: set sw=4 et:
