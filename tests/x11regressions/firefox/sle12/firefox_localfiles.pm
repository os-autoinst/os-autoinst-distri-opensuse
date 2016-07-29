# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Case#1436075 Firefox: Open local file with various types

use strict;
use base "x11test";
use testapi;

sub run() {
    mouse_hide(1);

    # Clean and Start Firefox
    x11_start_program("xterm -e \"killall -9 firefox;rm -rf .moz*\"");
    x11_start_program("firefox");
    assert_screen('firefox-launch', 90);

    # html
    send_key "alt-d";
    type_string "/usr/share/w3m/w3mhelp.html\n";
    assert_screen('firefox-local_files-html', 30);

    # wav
    send_key "alt-d";
    type_string "/usr/share/sounds/alsa/test.wav\n";
    assert_screen('firefox-local_files-wav', 30);

    # so
    send_key "alt-d";
    type_string "/usr/lib/libnss3.so\n";
    assert_screen('firefox-local_files-so', 30);
    send_key "esc";

    # Exit
    send_key "alt-f4";
    if (check_screen('firefox-save-and-quit', 4)) {
        # confirm "save&quit"
        send_key "ret";
    }
}
1;
# vim: set sw=4 et:
