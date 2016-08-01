# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Case#1436084: Firefox: Open IE MHTML Files

use strict;
use base "x11regressiontest";
use testapi;

sub run() {
    mouse_hide(1);

    # Fetch mht file to shm
    x11_start_program("wget " . autoinst_url . "/data/x11regressions/ie10.mht -O /dev/shm/ie10.mht");

    # Clean and Start Firefox
    x11_start_program("xterm -e \"killall -9 firefox;rm -rf .moz*\"");
    x11_start_program("firefox");
    assert_screen('firefox-launch', 90);

    send_key "ctrl-shift-a";
    assert_screen('firefox-addons_manager', 45);

    for my $i (1 .. 2) { send_key "tab"; }
    type_string "unmht\n";
    assert_and_click('firefox-mhtml-unmht');
    for my $i (1 .. 2) { send_key "tab"; }
    send_key "spc";
    assert_screen('firefox-mhtml-unmht_installed', 45);

    send_key "ctrl-w", 1;

    send_key "alt-d";
    type_string "file:///dev/shm/ie10.mht\n";
    assert_screen('firefox-mhtml-loadpage', 15);

    # Exit and Clear
    send_key "alt-f4";
    x11_start_program("rm /dev/shm/ie10.mht");

    if (check_screen('firefox-save-and-quit', 4)) {
        # confirm "save&quit"
        send_key "ret";
    }
}
1;
# vim: set sw=4 et:
