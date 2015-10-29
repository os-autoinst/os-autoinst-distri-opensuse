# Case#1436064: Firefox: Externally handled content

use strict;
use base "x11test";
use testapi;

sub run() {
    mouse_hide(1);

    my $ext_link = "http://mirror.bej.suse.com/dist/install/SLP/SLE-12-Server-GM/x86_64/dvd1/";

    # Clean and Start Firefox
    x11_start_program("xterm -e \"killall -9 firefox;rm -rf .moz*\"");
    x11_start_program("firefox");
    assert_screen('firefox-launch', 45);

    send_key "esc";
    sleep 1;
    send_key "alt-d";
    sleep 1;
    type_string $ext_link. "\n";

    assert_screen('firefox-extcontent-pageloaded', 35);
    send_key "/";
    sleep 1;
    type_string "license.tar.gz\n";

    assert_screen('firefox-extcontent-opening', 15);

    send_key "alt-o";
    sleep 1;
    send_key "ret";

    assert_screen('firefox-extcontent-archive_manager', 10);

    send_key "ctrl-q";

    # Exit
    send_key "alt-f4";

    if (check_screen('firefox-save-and-quit', 4)) {
        # confirm "save&quit"
        send_key "ret";
    }
}
1;
# vim: set sw=4 et:
