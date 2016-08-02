# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Case#1436111: Firefox: Preferences Change Saving

use strict;
use base "x11regressiontest";
use testapi;

sub run() {
    mouse_hide(1);

    my $changesaving_checktimestamp = "ll --time-style=full-iso .mozilla/firefox/*.default/prefs.js | cut -d' ' -f7";

    # Clean and Start Firefox
    x11_start_program("xterm");
    type_string "killall -9 firefox;rm -rf .moz*;firefox &>/dev/null &\n";
    assert_screen('firefox-launch', 90);

    send_key "alt-tab", 1;    #Switch to xterm
    type_string "$changesaving_checktimestamp > dfa\n";

    send_key "alt-tab", 1;    #Switch to firefox

    send_key "alt-e", 1;
    send_key "n";
    assert_screen('firefox-changesaving-preferences', 30);

    send_key "alt-shift-s";
    send_key "down";          #Show a blank page
    assert_screen('firefox-changesaving-showblankpage', 30);

    send_key "ctrl-w",  1;
    send_key "alt-tab", 1;    #Switch to xterm
    type_string "$changesaving_checktimestamp > dfb\n";
    send_key "ctrl-l", 1;
    type_string "diff dfa dfb\n";

    assert_screen('firefox-changesaving-diffresult', 30);
    type_string "rm df*\n", 1;    #Clear
    send_key "ctrl-d",      1;

    # Exit
    send_key "alt-f4";

    if (check_screen('firefox-save-and-quit', 30)) {
        # confirm "save&quit"
        send_key "ret";
    }
}
1;
# vim: set sw=4 et:
