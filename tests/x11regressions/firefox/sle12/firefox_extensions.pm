# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Case#1479189: Firefox: Add-ons - Extensions

use strict;
use base "x11test";
use testapi;

sub run() {
    mouse_hide(1);

    # Clean and Start Firefox
    x11_start_program("xterm -e \"killall -9 firefox;rm -rf .moz*\"");
    x11_start_program("firefox");
    assert_screen('firefox-launch', 45);

    assert_screen('firefox-extensions-no_flag', 45);
    send_key "ctrl-shift-a";
    assert_screen('firefox-addons_manager', 45);

    for my $i (1 .. 2) { send_key "tab"; }
    type_string "flagfox\n";
    assert_and_click('firefox-extensions-flagfox');
    for my $i (1 .. 2) { send_key "tab"; }
    send_key "spc";
    assert_screen('firefox-extensions-flagfox_installed', 45);

    send_key "alt-1";
    assert_screen('firefox-extensions-show_flag', 25);

    sleep 1;
    send_key "alt-2";
    assert_and_click('firefox-extensions-flagfox_installed');

    sleep 2;
    send_key "alt-1";
    assert_screen('firefox-extensions-no_flag', 45);

    # Exit
    for my $i (1 .. 2) { sleep 1; send_key "ctrl-w"; }

    if (check_screen('firefox-save-and-quit', 4)) {
        # confirm "save&quit"
        send_key "ret";
    }
}
1;
# vim: set sw=4 et:
