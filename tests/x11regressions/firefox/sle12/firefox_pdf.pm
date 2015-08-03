# Case#1436081: Firefox: Build-in PDF Viewer

use strict;
use base "x11test";
use testapi;

sub run() {
    mouse_hide(1);

    sub send_repkey($;$;$) {
        my $key = shift;
        my $times = shift;
        my $wait = shift || 0;
        for (my $i=1; $i <= $times; $i++) { 
            bmwqemu::log_call('send_key', key => $key);
            eval { $bmwqemu::backend->send_key($key); };
            bmwqemu::mydie("Error send_key key=$key: $@\n") if ($@);
            wait_idle() if $wait;
        }
    }

    # Clean and Start Firefox
    x11_start_program("xterm");
    type_string "killall -9 firefox;rm -rf .moz*;firefox &>/dev/null &\n";
    send_key "ctrl-d";
    assert_screen('firefox-launch',30);

    send_key "esc";
    send_key "alt-d";
    type_string "http://www.gnupg.org/gph/en/manual.pdf\n";

    assert_screen('firefox-pdf-load',45);

    sleep 2;
    send_repkey("tab",5);
    send_repkey("ret",2);
    assert_screen('firefox-pdf-zoom_out',5);

    send_key "tab";
    send_repkey("ret",4);
    assert_screen('firefox-pdf-zoom_in',5);

    send_key "tab";
    send_key "up";
    send_key "down"; #"Actual Size"
    send_key "ret";
    assert_screen('firefox-pdf-actual_size',5);

    send_key "tab";
    send_key "ret"; #Full Screen
    #assert_and_click('firefox-pdf-allow_fullscreen',5);
    mouse_set(550,170);
    mouse_click();
    sleep 1;
    mouse_hide(1);
    sleep 1;
    assert_screen('firefox-pdf-fullscreen',10);

    send_key "esc";
    send_repkey("tab",5);
    send_repkey("pgdn",6);
    assert_screen('firefox-pdf-pagedown',5);

    # Exit
    send_key "alt-f4";
    
    if (check_screen('firefox-save-and-quit', 4)) {
       # confirm "save&quit"
       send_key "ret";
    }
}
1;
# vim: set sw=4 et:
