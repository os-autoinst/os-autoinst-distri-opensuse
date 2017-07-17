# SUSE's openQA tests - FIPS tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Case #1560076 - FIPS: Firefox Mozilla NSS

# Summary: Add fips firefox nss test
# Maintainer: mitiao <mitiao@gmail.com>

use base "x11test";
use strict;
use testapi;

sub quit_firefox {
    send_key "alt-f4";
    if (check_screen("firefox-save-and-quit", 10)) {
        send_key "ret";
    }
}

sub run {
    # define fips password for firefox, and it should be consisted by:
    # - at least 8 characters
    # - at least one upper case
    # - at least one non-alphabet-non-number character (like: @-.=%)
    my $fips_password = 'openqa@SUSE';

    # launch firefox first and enable FIPS mode
    x11_start_program("firefox");
    assert_screen "firefox-launch", 90;
    send_key "alt-d";
    type_string "about:preferences#security\n";
    assert_screen "firefox-preferences-security";
    send_key "alt-shift-u";
    assert_screen "firefox-passwd-master_setting";
    type_string $fips_password;
    send_key "tab";
    type_string $fips_password;
    send_key "ret";
    assert_screen "firefox-password-change-succeeded";
    send_key "ret";
    send_key "alt-d";
    type_string "about:preferences#advanced\n";
    assert_and_click "firefox-ssl-advanced_certificate";
    wait_still_screen;
    send_key "alt-shift-d";
    assert_screen "firefox-device-manager";
    # Enable FIPS mode
    send_key "alt-shift-f";
    assert_screen "firefox-fips-password-inputfiled", 300;
    type_string $fips_password;
    send_key "ret";
    # No shortcut to close device manager, quit firefox directly
    quit_firefox;
    assert_screen "generic-desktop";

    # launch firefox again and check FIPS mode is enabled
    x11_start_program("firefox");
    assert_screen "firefox-fips-password-inputfiled", 90;
    type_string $fips_password;
    send_key "ret";
    # Need click on tab area twice to make sure it is selected
    assert_and_click "firefox-homepage", 90;
    assert_and_click "firefox-homepage";
    send_key "alt-d";
    type_string "about:preferences#advanced\n";
    assert_screen "firefox-preferences-advanced";
    send_key "alt-shift-d";
    assert_screen "firefox-device-manager";
    assert_screen "firefox-confirm-fips_enabled";
    quit_firefox;
    assert_screen "generic-desktop";
}

1;
# vim: set sw=4 et:
