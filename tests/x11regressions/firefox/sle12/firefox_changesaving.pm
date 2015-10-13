# Case#1436111: Firefox: Preferences Change Saving

use strict;
use base "x11test";
use testapi;

sub run() {
    mouse_hide(1);

    my $changesaving_checktimestamp="ll --time-style=full-iso .mozilla/firefox/*.default/prefs.js | cut -d' ' -f7";

    # Clean and Start Firefox
    x11_start_program("xterm");
    type_string "killall -9 firefox;rm -rf .moz*;firefox &>/dev/null &\n";
    assert_screen('firefox-launch',35);

    send_key "alt-tab", 1; #Switch to xterm
    type_string "$changesaving_checktimestamp > dfa\n";

    send_key "alt-tab", 1; #Switch to firefox

    send_key "alt-e", 1;
    send_key "n";
    assert_screen('firefox-changesaving-preferences',10);

    send_key "alt-shift-s";
    send_key "down"; #Show a blank page
    assert_screen('firefox-changesaving-showblankpage',10);

    send_key "ctrl-w", 1;
    send_key "alt-tab", 1; #Switch to xterm
    type_string "$changesaving_checktimestamp > dfb\n";
    send_key "ctrl-l", 1;
    type_string "diff dfa dfb\n";

    assert_screen('firefox-changesaving-diffresult',5);
    type_string "rm df*\n", 1;#Clear
    send_key "ctrl-d", 1;

    # Exit
    send_key "alt-f4";
    
    if (check_screen('firefox-save-and-quit', 4)) {
       # confirm "save&quit"
       send_key "ret";
    }
}
1;
# vim: set sw=4 et:
