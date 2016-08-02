# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Case#1436081: Firefox: Build-in PDF Viewer

use strict;
use base "x11regressiontest";
use testapi;

sub run() {
    mouse_hide(1);

    # Clean and Start Firefox
    x11_start_program("xterm -e \"killall -9 firefox;rm -rf .moz*\"");
    x11_start_program("firefox");
    assert_screen('firefox-launch', 90);

    send_key "esc";
    send_key "alt-d";
    type_string "http://www.gnupg.org/gph/en/manual.pdf\n";

    assert_screen('firefox-pdf-load', 90);

    sleep 1;
    for my $i (1 .. 2) { assert_and_click 'firefox-pdf-zoom_out_button'; }
    assert_screen('firefox-pdf-zoom_out', 30);

    send_key "tab";
    for my $i (1 .. 4) { assert_and_click 'firefox-pdf-zoom_in_button'; }
    assert_screen('firefox-pdf-zoom_in', 30);

    assert_and_click 'firefox-pdf-zoom_menu';
    sleep 1;
    assert_and_click 'firefox-pdf-zoom_menu_actual_size';    #"Actual Size"
    assert_screen('firefox-pdf-actual_size', 30);

    sleep 1;
    assert_and_click 'firefox-pdf-icon_fullscreen';          #Full Screen
    assert_and_click('firefox-pdf-allow_fullscreen');

    send_key "esc";
    sleep 1;
    assert_and_click "firefox-pdf-actual_size";
    assert_and_click "firefox-pdf-page";
    sleep 1;
    send_key "3";
    send_key "ret";
    sleep 1;
    assert_screen('firefox-pdf-pagedown', 30);

    # Exit
    send_key "alt-f4";

    if (check_screen('firefox-save-and-quit', 30)) {
        # confirm "save&quit"
        send_key "ret";
    }
}
1;
# vim: set sw=4 et:
