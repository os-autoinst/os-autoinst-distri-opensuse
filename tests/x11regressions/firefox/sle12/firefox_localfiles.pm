# Case#1436075 Firefox: Open local file with various types

use strict;
use base "x11test";
use testapi;

sub run() {
    mouse_hide(1);

    # Clean and Start Firefox
    x11_start_program("xterm -e \"killall -9 firefox;rm -rf .moz*\"");
    x11_start_program("firefox");
    assert_screen('firefox-launch',45);

    # html
    send_key "ctrl-o";
    send_key "down";
    type_string "/usr/share/w3m/w3mhelp.html\n";
    assert_screen('firefox-local_files-html',30);

    # wav
    send_key "ctrl-o";
    send_key "down";
    type_string "/usr/share/sounds/alsa/test.wav\n";
    assert_screen('firefox-local_files-wav',30);

    # so
    send_key "ctrl-o";
    send_key "down";
    type_string "/usr/lib/libnss3.so\n";
    assert_screen('firefox-local_files-so',30);
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
