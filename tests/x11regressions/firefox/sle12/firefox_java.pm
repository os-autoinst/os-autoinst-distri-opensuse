# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Case#1436069: Firefox: Java Plugin (IcedTea-Web)

use strict;
use base "x11test";
use testapi;

sub java_testing {
    sleep 1;
    send_key "ctrl-t";
    sleep 2;
    send_key "alt-d";
    type_string "http://www.java.com/en/download/installed.jsp?detect=jre\n";
    if (check_screen("oracle-cookies-handling", 30)) {
        assert_and_click "firefox-java-agree-and-proceed";
    }
}

sub run() {
    mouse_hide(1);

    # Clean and Start Firefox
    x11_start_program("xterm -e \"killall -9 firefox;rm -rf .moz* .config/iced* .cache/iced*\"");
    x11_start_program("firefox");
    assert_screen('firefox-launch', 90);

    send_key "ctrl-shift-a";

    assert_screen("firefox-java-addonsmanager", 10);

    send_key "/";
    sleep 1;
    type_string "iced\n";

    #Focus to "Available Add-ons"
    assert_and_click "firefox-java-myaddons";

    #Focus to "Ask to Activate"
    sleep 1;
    assert_and_click "firefox-java-asktoactivate";

    #Focus to "Never Activate"
    sleep 1;
    send_key "up";
    sleep 1;
    send_key "ret";

    assert_screen("firefox-java-neveractive", 10);

    java_testing();
    assert_screen("firefox-java-verifyfailed", 45);

    send_key "ctrl-w";

    for my $i (1 .. 2) { sleep 1; send_key "down"; }
    assert_screen("firefox-java-active", 10);

    java_testing();

    # following steps were not needful in newer firefox
    # assert_screen("firefox-java-security",50);
    # assert_and_click "firefox-java-securityrun";
    # assert_screen("firefox-java-run_confirm",10);
    # send_key "ret";
    assert_screen("firefox-java-verifypassed", 45);

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
