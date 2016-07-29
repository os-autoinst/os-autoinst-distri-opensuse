# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Case#1436066: Firefox: HTTP Headers

use strict;
use base "x11test";
use testapi;

sub run() {
    mouse_hide(1);

    # Clean and Start Firefox
    x11_start_program("xterm -e \"killall -9 firefox;rm -rf .moz*\"");
    x11_start_program("firefox");
    assert_screen('firefox-launch', 90);

    send_key "esc";
    send_key "ctrl-shift-q", 1;
    send_key "alt-d",        1;
    type_string "www.gnu.org\n";
    assert_screen('firefox-headers-website', 45);

    sleep 10;
    send_key "down";
    assert_screen('firefox-headers-first_item', 5);

    send_key "shift-f10";
    #"Edit and Resend"
    send_key "r";

    assert_screen('firefox-headers-user_agent', 5);

    # Exit
    send_key "alt-f4";

    if (check_screen('firefox-save-and-quit', 4)) {
        # confirm "save&quit"
        send_key "ret";
    }
}
1;
# vim: set sw=4 et:
