# Case#1436069: Firefox: Java Plugin (IcedTea-Web)

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

    sub java_testing {
        sleep 1; send_key "ctrl-t";
        sleep 2; send_key "alt-d";
        type_string "http://www.java.com/en/download/installed.jsp?detect=jre\n";
    }

    # Clean and Start Firefox
    x11_start_program("xterm");
    type_string "killall -9 firefox;rm -rf .moz* .config/iced* .cache/iced*;firefox &>/dev/null &\n";
    send_key "ctrl-d";
    assert_screen('firefox-launch',30);

    send_key "ctrl-shift-a";

    assert_screen("firefox-java-addonsmanager",10);

    send_key "/";
    type_string "iced\n";

    #Focus to "Available Add-ons"
    send_repkey("tab",5);

    #Focus to "My Add-ons"
    sleep 1; send_key "up";
    sleep 1; send_key "tab";
    sleep 1; send_key "down";

    #Focus to "Ask to Activate"
    sleep 1; send_repkey("tab",2);

    #Focus to "Never Activate"
    sleep 1; send_key "up";

    assert_screen("firefox-java-neveractive",10);

    java_testing();
    assert_screen("firefox-java-verifyfailed",45);

    send_key "ctrl-w";

    sleep 1; send_repkey("down",2);
    assert_screen("firefox-java-active",10);

    java_testing();
    assert_screen("firefox-java-security",50);

    sleep 1; send_repkey("tab",3);
    send_key "spc";

    check_screen("firefox-java-run_confirm",10);
    send_key "ret";
    assert_screen("firefox-java-verifypassed",45);

    # Exit
    send_key "alt-f4", 1;
    send_key "spc";
    
    if (check_screen('firefox-save-and-quit', 4)) {
       # confirm "save&quit"
       send_key "ret";
    }
}
1;
# vim: set sw=4 et:
