# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Case#1479522: Firefox: Web Developer Tools

use strict;
use base "x11test";
use testapi;

sub run() {
    mouse_hide(1);

    # Clean and Start Firefox
    x11_start_program("xterm -e \"killall -9 firefox;rm -rf .moz*\"");
    x11_start_program("firefox");
    assert_screen('firefox-launch', 30);

    send_key "esc";
    sleep 1;
    send_key "alt-d";
    sleep 1;
    type_string "opensuse.org\n";
    assert_screen('firefox-developertool-opensuse', 45);

    sleep 2;
    send_key "ctrl-shift-i";
    assert_screen('firefox-developertool-gerneral', 10);
    sleep 2;
    assert_and_click "firefox-developertool-click_element";
    sleep 1;
    assert_and_click "firefox-developertool-check_element";

    sleep 2;
    assert_screen("firefox-developertool-element", 10);

    sleep 1;
    assert_and_click "firefox-developertool-console_button";
    sleep 1;
    send_key "f5";
    assert_screen("firefox-developertool-console_contents", 15);

    # Exit
    send_key "alt-f4";

    if (check_screen('firefox-save-and-quit', 4)) {
        # confirm "save&quit"
        send_key "ret";
    }
}
1;
# vim: set sw=4 et:
