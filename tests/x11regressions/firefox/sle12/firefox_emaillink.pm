# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Case#1436117 Firefox: Email Link

use strict;
use base "x11regressiontest";
use testapi;

sub run() {
    mouse_hide(1);

    # Clean and Start Firefox
    x11_start_program("xterm -e \"killall -9 firefox;rm -rf .config/evolution;rm -rf .moz*\"");
    x11_start_program("firefox");
    assert_screen('firefox-gnome', 90);

    # Email link
    send_key "alt-f";
    send_key "e";
    assert_screen('firefox-email_link-welcome', 90);

    send_key "alt-o";

    sleep 1;
    send_key "alt-o";

    sleep 1;
    send_key "alt-a";
    type_string 'test@suse.com';
    send_key "alt-o";

    sleep 1;
    send_key "alt-s";    #Skip

    assert_screen('firefox-email_link-settings_receiving', 90);
    send_key "alt-s";    #Server
    type_string "imap.suse.com";
    send_key "alt-n";    #Username
    type_string "test";
    send_key "alt-o";

    sleep 1;
    send_key "alt-o";

    assert_screen('firefox-email_link-settings_sending', 30);
    send_key "alt-s";    #Server
    type_string "smtp.suse.com";
    send_key "alt-o";

    sleep 1;
    send_key "alt-o";

    sleep 1;
    send_key "alt-a";

    assert_screen('firefox-email_link-send', 30);

    send_key "esc";
    sleep 2;

    # Exit
    send_key "alt-f4";
    if (check_screen('firefox-save-and-quit', 30)) {
        # confirm "save&quit"
        send_key "ret";
    }
}
1;
# vim: set sw=4 et:
