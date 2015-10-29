# Case#1479413: Firefox: Full Screen Browsing

use strict;
use base "x11test";
use testapi;

sub run() {
    mouse_hide(1);

    # Clean and Start Firefox
    x11_start_program("xterm -e \"killall -9 firefox;rm -rf .moz*\"");
    x11_start_program("firefox");
    assert_screen('firefox-launch', 25);

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
