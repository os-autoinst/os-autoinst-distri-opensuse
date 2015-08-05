# Case#1436066: Firefox: HTTP Headers

use strict;
use base "x11test";
use testapi;

sub run() {
    mouse_hide(1);

    # Clean and Start Firefox
    x11_start_program("xterm");
    type_string "killall -9 firefox;rm -rf .moz*;firefox &>/dev/null &\n";
    send_key "ctrl-d";
    assert_screen('firefox-launch',35);

    send_key "esc";
    sleep 1;
    send_key "ctrl-shift-q";
    sleep 1;
    send_key "alt-d";
    type_string "http://www.gnu.org\n";
    check_screen('firefox-headers-website',45);

    send_key "down";
    assert_screen('firefox-headers-first_item',5);

    send_key "shift-f10";
    #"Edit and Resend"
    send_key "r";

    assert_screen('firefox-headers-user_agent',5);

    # Exit
    send_key "alt-f4";
    
    if (check_screen('firefox-save-and-quit', 4)) {
       # confirm "save&quit"
       send_key "ret";
    }
}
1;
# vim: set sw=4 et:
