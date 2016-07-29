# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Case#1436067: Firefox: SSL Certificate

use strict;
use base "x11test";
use testapi;

sub run() {
    mouse_hide(1);

    # Clean and Start Firefox
    x11_start_program("xterm -e \"killall -9 firefox;rm -rf .moz*\"");
    x11_start_program("firefox");
    assert_screen('firefox-launch', 90);

    send_key "esc";
    send_key "alt-d";
    type_string "https://build.suse.de\n";

    check_screen('firefox-ssl-untrusted', 15);

    send_key "tab";
    send_key "tab";
    send_key "tab";
    send_key "ret";
    send_key "tab";
    send_key "ret";

    assert_screen('firefox-ssl-addexception', 15);
    send_key "alt-c";

    assert_screen('firefox-ssl-loadpage', 35);

    send_key "alt-e";
    send_key "n", 1;

    assert_and_click('firefox-ssl-preference_advanced');
    assert_and_click('firefox-ssl-advanced_certificate');

    send_key "alt-shift-c";

    sleep 1;
    type_string "CNNIC";
    send_key "down";

    sleep 1;
    send_key "alt-e";

    sleep 1;
    send_key "spc";
    assert_screen('firefox-ssl-edit_ca_trust', 5);
    send_key "ret";


    sleep 1;
    assert_and_click('firefox-ssl-certificate_servers');

    send_key "pgdn";
    send_key "pgdn";

    sleep 1;
    assert_screen('firefox-ssl-servers_cert', 5);

    send_key "alt-f4", 1;
    send_key "ctrl-w";

    send_key "alt-d";
    type_string "https://www.cnnic.cn/\n";
    assert_screen('firefox-ssl-connection_untrusted', 65);

    # Exit
    send_key "alt-f4";

    if (check_screen('firefox-save-and-quit', 4)) {
        # confirm "save&quit"
        send_key "ret";
    }
}
1;
# vim: set sw=4 et:
