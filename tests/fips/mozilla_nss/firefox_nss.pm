# SUSE's openQA tests - FIPS tests
#
# Copyright © 2016-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Case #1560076 - FIPS: Firefox Mozilla NSS
#
# Summary: FIPS mozilla-nss test for firefox : firefox_nss
#
# Maintainer: Ben Chou <bchou@suse.com>
# Tag: poo#47018, poo#58079, poo#71458, poo#77140, poo#77143

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;
use Utils::Architectures 'is_aarch64';

sub quit_firefox {
    send_key "alt-f4";
    if (check_screen("firefox-save-and-quit", 30)) {
        assert_and_click('firefox-click-close-tabs');
    }
}

sub run {
    my ($self) = @_;
    select_console 'root-console';

    # Define FIPS password for firefox, and it should be consisted by:
    # - at least 8 characters
    # - at least one upper case
    # - at least one non-alphabet-non-number character (like: @-.=%)
    my $fips_password = 'openqa@SUSE';

    select_console 'x11';
    x11_start_program('firefox https://html5test.opensuse.org', target_match => 'firefox-html-test', match_timeout => 360);

    # Firfox Preferences
    send_key "alt-e";
    wait_still_screen 2;
    send_key "n";
    assert_screen('firefox-preferences');

    # Search "Passwords" section
    type_string "Use a master", timeout => 2;    # Search "Passwords" section
    assert_and_click('firefox-master-password-checkbox');
    assert_screen('firefox-passwd-master_setting');

    # Set the Master Password
    type_string $fips_password;
    send_key "tab";
    type_string $fips_password;
    send_key "ret";
    assert_screen "firefox-password-change-succeeded";
    send_key "ret";
    wait_still_screen 3;
    send_key "ctrl-f";
    send_key "ctrl-a";
    type_string "certificates";    # Search "Certificates" section
    send_key "tab";
    wait_still_screen 2;

    # Change from "alt-shift-d" hotkey to needles match Security Device
    # send_key "alt-shift-d" is fail to react in s390x/aarch64 usually
    assert_and_click('firefox-click-security-device');
    assert_screen "firefox-device-manager";

    # Add condition in FIPS_ENV_MODE & Remove hotkey
    if (get_var('FIPS_ENV_MODE')) {
        assert_and_click('firefox-click-enable-fips', timeout => 2);
    }

    # Enable FIPS mode
    # Remove send_key "alt-shift-f";
    assert_screen "firefox-confirm-fips_enabled";
    send_key "esc";    # Quit device manager

    # Close Firefox
    quit_firefox;

    # Add more time for aarch64 due to worker performance problem
    my $waittime = 60;
    $waittime += 60 if is_aarch64;
    assert_screen("generic-desktop", $waittime);

    # Use the ps check if the bug happened bsc#1178552
    # Add the ps to list which process is not closed while timeout
    select_console 'root-console';

    my $ret = script_run("ps -ef | grep firefox | grep childID | wc -l | grep '0'");
    diag "---$ret---";
    if ($ret == 1) {
        script_run('ps -ef | grep firefox');
        diag "---ret_pass---";
        record_info('Firefox_ps', "Firefox process is already closed.");
    }
    else {
        script_run('ps -ef | grep firefox | grep childID');
        diag "---ret_fail---";
        die 'firefox is not correctly closed';
    }

    select_console 'x11', await_console => 0;    # Go back to X11

    # "start_firefox" will be not used, since the master password is
    # required when firefox launching in FIPS mode
    # x11_start_program('firefox --setDefaultBrowser https://html5test.opensuse.org', target_match => 'firefox-fips-password-inputfiled', match_timeout => 180);
    # Adjust the 2nd Firefox launch via xterm as workaround to avoid the race condition during password interaction while internet connection busy
    x11_start_program('xterm');
    mouse_hide(1);
    type_string("firefox --setDefaultBrowser https://html5test.opensuse.org\n");
    assert_screen("firefox-passowrd-typefield", 120);

    # Add max_interval while type password and extend time of click needle match
    type_string($fips_password, max_interval => 2);
    assert_and_click("firefox-enter-password-OK", 120);
    wait_still_screen 10;

    # Add a condition to avoid the password missed input
    # Retype password again once the password missed input
    # The problem frequently happaned in aarch64
    if (check_screen('firefox-password-typefield-miss')) {
        record_soft_failure "Firefox password is missing to input, see poo#77143";
        type_string($fips_password, max_interval => 2);
        send_key "ret";
    }
    assert_screen("firefox-url-loaded", 20);

    # Firfox Preferences
    send_key "alt-e";
    wait_still_screen 2;
    send_key "n";
    assert_screen('firefox-preferences');
    type_string "certificates";    # Search "Certificates" section
    send_key "tab";
    wait_still_screen 2;

    # Change from "alt-shift-d" hotkey to needles match Security Device
    # send_key "alt-shift-d" is fail to react in s390x/aarch64 usually
    assert_and_click('firefox-click-security-device');
    assert_screen "firefox-device-manager";
    assert_screen "firefox-confirm-fips_enabled";

    # Close Firefox
    quit_firefox;
    assert_screen("generic-desktop", 20);
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}
1;
