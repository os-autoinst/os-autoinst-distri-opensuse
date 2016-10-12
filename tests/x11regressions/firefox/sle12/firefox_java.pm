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

# Summary: Test java plugin integration in firefox
# Maintainer: wnereiz <wnereiz@gmail.com>

use strict;
use base "x11regressiontest";
use testapi;

sub java_testing {
    sleep 1;
    send_key "ctrl-t";
    sleep 2;
    send_key "alt-d";
    type_string "http://www.java.com/en/download/installed.jsp?detect=jre\n";

    if (check_screen('firefox-java-security', 10)) {
        assert_and_click('firefox-java-securityrun');
        assert_and_click('firefox-java-run_confirm');
        assert_screen("firefox-java-verifypassed", 90);
    }

    assert_and_click "firefox-java-agree-and-proceed" if (check_screen("oracle-cookies-handling"));
}

sub run() {
    mouse_hide(1);

    # Clean and Start Firefox
    x11_start_program("xterm -e \"killall -9 firefox;rm -rf .moz* .config/iced* .cache/iced*\"");
    x11_start_program("firefox");
    assert_screen('firefox-launch', 90);

    assert_and_click('firefox-logo');
    sleep 1;
    send_key "ctrl-shift-a";

    assert_screen("firefox-java-addonsmanager");

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

    assert_screen("firefox-java-neveractive");

    java_testing();
    assert_screen("firefox-java-verifyfailed", 90);

    send_key "ctrl-w";

    for my $i (1 .. 2) { sleep 1; send_key "down"; }
    assert_screen("firefox-java-active", 60);

    java_testing();

    assert_screen("firefox-java-verifypassed", 90);

    # Exit
    send_key "alt-f4";
    if (check_screen('firefox-save-and-quit')) {
        # confirm "save&quit"
        send_key "ret";
    }
}
1;
# vim: set sw=4 et:
