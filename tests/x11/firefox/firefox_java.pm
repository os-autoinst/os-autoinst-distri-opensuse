# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test java plugin integration in firefox (Case#1436069)
# Maintainer: wnereiz <wnereiz@gmail.com>

use strict;
use base "x11test";
use testapi;
use version_utils qw(is_leap is_sle is_tumbleweed);

sub java_testing {
    my ($self) = @_;

    send_key "ctrl-t";
    assert_screen 'firefox-new-tab';

    $self->firefox_open_url('http://www.java.com/en/download/installed.jsp?detect=jre');
    wait_still_screen 3;
    if (check_screen('oracle-cookies-handling')) {
        assert_and_click('oracle-cookie-settings');
        assert_and_click('oracle-cookie-advanced-settings');
        assert_and_click('oracle-function-cookies');
        assert_and_click('oracle-ad-cookies');
        assert_and_click('oracle-submit-preferences');
        assert_and_click('oracle-cookies-close');
    }

    wait_still_screen 3;
    if (check_screen('firefox-java-security', 0)) {
        assert_and_click('firefox-java-securityrun');
        assert_and_click('firefox-java-run_confirm');
    }

    wait_still_screen 3;
    assert_screen([qw(firefox-java-verifyversion firefox-java-verifyfailed firefox-java-verifypassed firefox-newer-java-available)]);

    if (match_has_tag 'firefox-java-verifyversion') {
        assert_and_click "firefox-java-verifyversion";
    }
    # Newer version of java is available
    if (match_has_tag 'firefox-newer-java-available') {
        record_info('Newer java version available',
            "Aim of the test is to verify that java is installed and works in browser, it's acceptable that it's not always latest version.");
        return;
    }
    return if match_has_tag 'firefox-java-verifyfailed';
    return if match_has_tag 'firefox-java-verifypassed';
}


sub run {
    my ($self) = @_;

    # FF 56 no longer support NPAPI plugins, e.g. Java
    if (is_sle('15+') || is_leap('15.0+') || is_tumbleweed) {
        record_info('NPAPI plugins not supported',
            "FF 56 no longer supports supports NPAPI plugins, e.g. Java, so the test would fail in current distribution releases.");
        return;
    }

    $self->start_firefox_with_profile;

    send_key "ctrl-shift-a";

    assert_screen("firefox-java-addonsmanager");
    assert_and_click('firefox-extensions');

    send_key "/";
    type_string "iced\n";

    #Focus to "Available Add-ons"
    assert_and_click "firefox-java-myaddons";
    wait_still_screen 3;

    #Focus to "Ask to Activate"
    assert_and_click "firefox-java-asktoactivate";

    #Focus to "Never Activate"
    wait_still_screen 3;
    send_key "up";
    wait_still_screen 3;
    send_key "ret";

    assert_screen("firefox-java-neveractive");

    $self->java_testing;
    assert_screen("firefox-java-verifyfailed", 90);

    send_key "ctrl-w";

    #Focus to "Always Activate"
    for my $i (1 .. 2) { send_key "down"; }
    assert_screen("firefox-java-active", 60);

    $self->java_testing;
    # If java version is not latest in official repos
    assert_screen([qw(firefox-java-verifypassed firefox-newer-java-available)], 90);

    $self->exit_firefox;
}
1;
