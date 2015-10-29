# Case#1479188: Firefox: Add-ons - Plugins

use strict;
use base "x11test";
use testapi;

sub run() {
    mouse_hide(1);

    # Clean and Start Firefox
    x11_start_program("xterm -e \"killall -9 firefox;rm -rf .moz*\"");
    x11_start_program("firefox");
    assert_screen('firefox-launch', 45);

    send_key "ctrl-shift-a";
    sleep 1;
    for my $i (1 .. 3) { send_key "tab"; }
    for my $i (1 .. 3) { send_key "down"; }

    sleep 1;
    assert_screen('firefox-plugins-overview_01', 10);

    for my $i (1 .. 2) { send_key "tab"; }
    send_key "pgdn";
    sleep 1;
    assert_screen('firefox-plugins-overview_02', 10);

    sleep 1;
    assert_and_click('firefox-plugins-check_update');
    assert_screen('firefox-plugins-update_page', 35);

    # Exit
    send_key "alt-f4";
    sleep 2;
    send_key "ret";

    if (check_screen('firefox-save-and-quit', 4)) {
        # confirm "save&quit"
        send_key "ret";
    }
}
1;
# vim: set sw=4 et:
