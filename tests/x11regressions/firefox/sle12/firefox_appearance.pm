# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Case#1479190: Firefox: Add-ons - Appearance

use strict;
use base "x11test";
use testapi;

sub run() {
    mouse_hide(1);

    # Clean and Start Firefox
    x11_start_program("xterm -e \"killall -9 firefox;rm -rf .moz*\"");
    x11_start_program("firefox");
    assert_screen('firefox-launch', 90);

    send_key "ctrl-shift-a";
    assert_and_click('firefox-appearance-tabicon');
    assert_screen('firefox-appearance-default', 10);

    sleep 1;
    send_key "alt-d";
    sleep 1;
    type_string "addons.mozilla.org/en-US/firefox/addon/opensuse\n";
    assert_screen('firefox-appearance-mozilla_addons', 35);
    send_key "alt-f10";
    assert_and_click "firefox-appearance-addto";
    sleep 1;
    send_key "alt-a";
    assert_screen('firefox-appearance-installed', 35);

    # Exit
    for my $i (1 .. 2) { sleep 1; send_key "ctrl-w"; }

    if (check_screen('firefox-save-and-quit', 4)) {
        # confirm "save&quit"
        send_key "ret";
    }
}
1;
# vim: set sw=4 et:
