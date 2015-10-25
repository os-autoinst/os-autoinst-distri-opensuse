# Case#1479412: Firefox: Private Browsing

use strict;
use base "x11test";
use testapi;

sub run() {
    mouse_hide(1);

    # Clean and Start Firefox
    x11_start_program("xterm -e \"killall -9 firefox;rm -rf .moz*\"");
    x11_start_program("firefox");
    assert_screen('firefox-launch', 30);

    send_key "ctrl-shift-p";
    sleep 5;

    send_key "alt-d";
    type_string "twitter.com\n";
    assert_screen('firefox-private-twitter', 45);
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
