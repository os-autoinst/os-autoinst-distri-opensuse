# Case#1436117 Firefox: Email Link

use strict;
use base "x11test";
use testapi;

sub run() {
    mouse_hide(1);

    # Clean and Start Firefox
    x11_start_program("xterm");
    type_string "killall -9 firefox;rm -rf .config/evolution;rm -rf .mozilla;firefox &>/dev/null &\n";
    sleep 1;
    send_key "ctrl-d";
    assert_screen('firefox-gnome',45);

    # Email link
    send_key "alt-f";
    send_key "e";
    assert_screen('firefox-email_link-welcome',30);

    send_key "alt-o";

    sleep 1; send_key "alt-o";

    sleep 1;
    send_key "alt-a";
    type_string 'test@suse.com';
    send_key "alt-o";

    sleep 1; send_key "alt-s"; #Skip

    assert_screen('firefox-email_link-settings_receiving',30);
    send_key "alt-s"; #Server
    type_string "imap.suse.com";
    send_key "alt-n"; #Username
    type_string "test";
    send_key "alt-o";

    sleep 1; send_key "alt-o";

    assert_screen('firefox-email_link-settings_sending',10);
    send_key "alt-s"; #Server
    type_string "smtp.suse.com";
    send_key "alt-o";

    sleep 1; send_key "alt-o";

    sleep 1; send_key "alt-a";

    assert_screen('firefox-email_link-send',10);

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
