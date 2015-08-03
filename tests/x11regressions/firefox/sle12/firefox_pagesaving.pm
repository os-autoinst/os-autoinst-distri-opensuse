# Case#1436102: Firefox: Page Saving

use strict;
use base "x11test";
use testapi;

sub run() {
    mouse_hide(1);

    # Clean and Start Firefox
    x11_start_program("xterm");
    type_string "killall -9 firefox;rm -rf .moz* Downloads/*;firefox &>/dev/null &\n";
    assert_screen('firefox-launch',30);

    send_key "esc";
    send_key "alt-d";
    type_string "http://www.mozilla.org/en-US\n";

    check_screen('firefox-pagesaving-load',45);

    send_key "ctrl-s";
    check_screen('firefox-pagesaving-saveas',10);

    send_key "alt-s";
    sleep 5;

    # Exit
    send_key "alt-f4";
    
    if (check_screen('firefox-save-and-quit', 4)) {
       # confirm "save&quit"
       send_key "ret";
    }

    send_key "ctrl-l";
    type_string "ls Downloads/\n";
    assert_screen('firefox-pagesaving-downloads',10);
    type_string "rm -rf Downloads/*\n";
    send_key "ctrl-d";


}
1;
# vim: set sw=4 et:
