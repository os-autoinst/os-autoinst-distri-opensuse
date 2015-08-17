# Case#1436067: Firefox: SSL Certificate

use strict;
use base "x11test";
use testapi;

sub run() {
    mouse_hide(1);

    # Clean and Start Firefox
    x11_start_program("xterm -e \"killall -9 firefox;rm -rf .moz*\"");
    x11_start_program("firefox");
    assert_screen('firefox-launch',45);

    send_key "esc";
    send_key "alt-d";
    type_string "https://build.suse.de\n";

    check_screen('firefox-ssl-untrusted',15);

    send_key "tab";
    send_key "tab";
    send_key "tab";
    send_key "ret";
    send_key "tab";
    send_key "ret";

    assert_screen('firefox-ssl-addexception',15);
    send_key "alt-c";

    assert_screen('firefox-ssl-loadpage',35);

    send_key "alt-e";
    sleep 1;
    send_key "n";

    sleep 2;
    assert_and_click('firefox-ssl-preference_advanced');

    sleep 1;
    assert_and_click('firefox-ssl-advanced_certificate');

    send_key "alt-s";

    sleep 1;
    type_string "CNNIC";
    send_key "down";

    sleep 1;
    send_key "alt-e";

    sleep 1;
    send_key "spc";
    assert_screen('firefox-ssl-edit_ca_trust',5);
    send_key "ret";
    

    sleep 1;
    assert_and_click('firefox-ssl-certificate_servers');

    send_key "pgdn";
    send_key "pgdn";

    sleep 1;
    assert_screen('firefox-ssl-servers_cert',5);

    send_key "alt-f4";
    send_key "alt-f4";

    send_key "alt-d";
    type_string "https://www.cnnic.cn/\n";
    assert_screen('firefox-ssl-connection_untrusted',65);

    # Exit
    send_key "alt-f4";
    
    if (check_screen('firefox-save-and-quit', 4)) {
       # confirm "save&quit"
       send_key "ret";
    }
}
1;
# vim: set sw=4 et:
