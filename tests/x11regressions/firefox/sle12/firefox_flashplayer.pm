# Case#1436061: Firefox: Flash Player

use strict;
use base "x11test";
use testapi;

sub run() {
    mouse_hide(1);

    # Clean and Start Firefox
    x11_start_program("xterm");
    type_string "killall -9 firefox;rm -rf .moz*;firefox &>/dev/null &\n";
    send_key "ctrl-d";
    assert_screen('firefox-launch',30);

    send_key "esc";
    send_key "alt-d";
    type_string "http://www.adobe.com/software/flash/about/\n";
    assert_screen('firefox-flashplayer-verify_loaded',45);

    send_key "pgdn";
    assert_screen('firefox-flashplayer-verify',25);

    send_key "esc";
    send_key "alt-d";
    type_string "https://www.youtube.com/watch?v=Z4j5rJQMdOU\n";
    assert_screen('firefox-flashplayer-video_loaded',45);

    # Exit
    send_key "alt-f4";
    
    if (check_screen('firefox-save-and-quit', 4)) {
       # confirm "save&quit"
       send_key "ret";
    }
}
1;
# vim: set sw=4 et:
