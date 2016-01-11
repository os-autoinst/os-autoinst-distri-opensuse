# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Case#1436061: Firefox: Flash Player

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
    send_key "alt-d";
    type_string "http://www.adobe.com/software/flash/about/\n";
    assert_screen('firefox-flashplayer-verify_loaded', 45);

    send_key "pgdn";
    assert_screen('firefox-flashplayer-verify', 25);

    send_key "esc";
    send_key "alt-d";
    type_string "https://www.youtube.com/watch?v=Z4j5rJQMdOU\n";
    assert_screen('firefox-flashplayer-video_loaded', 45);

    # Exit
    send_key "alt-f4";

    if (check_screen('firefox-save-and-quit', 4)) {
        # confirm "save&quit"
        send_key "ret";
    }
}
1;
# vim: set sw=4 et:
