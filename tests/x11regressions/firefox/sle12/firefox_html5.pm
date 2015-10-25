# Case#1479221: Firefox: HTML5 Video

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
    type_string "youtube.com/html5\n";

    assert_screen('firefox-html5-youtube', 35);
    send_key "pgdn";
    send_key "up";
    sleep 1;
    assert_screen('firefox-html5-support', 5);
    assert_and_click('firefox-html5-request');

    assert_screen('firefox-html5-youtube', 35);
    send_key "pgdn";
    send_key "up";
    assert_screen('firefox-html5-enabled', 5);

    sleep 1;
    send_key "esc";
    send_key "alt-d";
    type_string "youtube.com/watch?v=Z4j5rJQMdOU\n";
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
