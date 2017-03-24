# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test java plugin integration in firefox (Case#1436069)
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

    wait_still_screen 3;

    for (my $counter = 0; $counter < 6; $counter++) {

        assert_screen(
            [
                qw(firefox-reader-view firefox-java-verifyversion firefox-java-security oracle-cookies-handling firefox-java-verifyfailed firefox-java-verifypassed)
            ]);
        if (match_has_tag 'firefox-reader-view') {
            assert_and_click('firefox-reader-close');
        }

        if (match_has_tag 'firefox-java-security') {
            assert_and_click('firefox-java-securityrun');
            assert_and_click('firefox-java-run_confirm');
        }
        if (match_has_tag "oracle-cookies-handling") {
            assert_and_click "firefox-java-agree-and-proceed";
        }
        # Click the "Verify Java version" button
        if (match_has_tag 'firefox-java-verifyversion') {
            assert_and_click "firefox-java-verifyversion";
        }
        return if match_has_tag 'firefox-java-verifyfailed';
        return if match_has_tag 'firefox-java-verifypassed';
    }

}

sub run() {
    my ($self) = @_;
    $self->start_firefox;

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

    #Focus to "Always Activate"
    for my $i (1 .. 2) { sleep 1; send_key "down"; }
    assert_screen("firefox-java-active", 60);

    java_testing();
    assert_screen("firefox-java-verifypassed", 90);

    $self->exit_firefox;
}
1;
# vim: set sw=4 et:
