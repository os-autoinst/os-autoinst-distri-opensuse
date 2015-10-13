# Case#1479557: Firefox: RSS Button

use strict;
use base "x11test";
use testapi;

sub run() {
    mouse_hide(1);

    # Clean and Start Firefox
    x11_start_program("xterm -e \"killall -9 firefox;rm -rf .moz*\"");
    x11_start_program("firefox");
    assert_screen('firefox-launch',35);

    send_key "alt-v", 1;
    send_key "t";
    send_key "c";

    assert_and_click "firefox-rss-close_hint";
    assert_and_click "firefox-click-scrollbar";
    assert_and_click ("firefox-rss-button","right");

    send_key "a";
    send_key "ctrl-w";
    send_key "alt-f10";
    assert_screen("firefox-rss-button_disabled",15);

    send_key "esc";
    send_key "alt-d";
    type_string "www.gnu.org\n";

    assert_and_click "firefox-rss-button_enabled", "left", 10;
    assert_screen("firefox-rss-page",35);

    # Exit
    send_key "alt-f4";
    
    if (check_screen('firefox-save-and-quit', 4)) {
       # confirm "save&quit"
       send_key "ret";
    }
}
1;
# vim: set sw=4 et:
