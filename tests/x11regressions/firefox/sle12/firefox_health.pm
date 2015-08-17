# Case#1479504: Firefox: Health Report

use strict;
use base "x11test";
use testapi;

sub run() {
    mouse_hide(1);

    # Clean and Start Firefox
    x11_start_program("xterm -e \"killall -9 firefox;rm -rf .moz*\"");
    x11_start_program("firefox");
    assert_screen('firefox-launch',30);

    send_key "alt-h";
    sleep 1;
    send_key "e";
    check_screen('firefox-health-report',15);

    
    send_key "/";
    sleep 1;
    type_string "raw data\n";
    check_screen('firefox-health-report',15);

    # Exit
    send_key "alt-f4";
    
    if (check_screen('firefox-save-and-quit', 4)) {
       # confirm "save&quit"
       send_key "ret";
    }
}
1;
# vim: set sw=4 et:
