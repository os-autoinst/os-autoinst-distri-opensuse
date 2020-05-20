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
# Tag: poo#47018, poo#58079, poo#65375, poo#67054

use base "x11test";
use strict;
use warnings;
use testapi;

sub quit_firefox {
    send_key "alt-f4";
    if (check_screen("firefox-save-and-quit", 10)) {
        send_key "ret";
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

    type_string "Passwords";    # Search "Passwords" section
    send_key "tab";             # Hide blinking cursor in the search box
    wait_still_screen 2;
    # Use a master password
    send_key_until_needlematch("firefox-use-a-master-password", "tab", 20, 1);
    send_key "spc";
    assert_screen('firefox-passwd-master_setting');

    type_string $fips_password;
    send_key "tab";
    type_string $fips_password;
    send_key "ret";
    assert_screen "firefox-password-change-succeeded";
    send_key "ret";
    wait_still_screen 3;
    send_key "ctrl-f";
    send_key "ctrl-a";

    # Search "Certificates" section
    type_string "certificates";
    send_key "tab";
    wait_still_screen 2;

    # Device Manager
    send_key_until_needlematch("firefox-security-devices", "tab", 20, 1);
    send_key "spc";
    assert_screen "firefox-device-manager";

    # Enable the FIPS Mode in ENV Mode
    # FIPS Enabled in Kernel Mode is set by default in Firefox preference
    if (get_var("FIPS_ENV_MODE")) {
        send_key_until_needlematch("firefox-enable-fips", "tab", 20, 1);
        send_key "spc";
        assert_screen "firefox-confirm-fips_enabled";
    }
    else {
        assert_screen "firefox-device-manager_fips-kernel-mode";
    }

    # Quit device manager
    send_key "esc";    # Quit device manager

    # Quit Firefox and back to desktop
    quit_firefox;
    assert_screen "generic-desktop";

    # "start_firefox" will be not used, since the master password is
    # required when firefox launching in FIPS mode
    x11_start_program('firefox --setDefaultBrowser https://html5test.opensuse.org', target_match => 'firefox-fips-password-inputfiled');
    type_string $fips_password;
    send_key "ret";
    assert_screen "firefox-url-loaded";

    # Firfox Preferences
    send_key "alt-e";
    wait_still_screen 2;
    send_key "n";
    assert_screen('firefox-preferences');

    # Search "Certificates" section
    type_string "certificates";
    send_key "tab";
    wait_still_screen 2;

    # Device Manager
    send_key_until_needlematch("firefox-security-devices", "tab", 20, 1);
    send_key "spc";
    assert_screen "firefox-device-manager";

    # Confirm FIPS Mode is enabled in ENV Mode
    if (get_var("FIPS_ENV_MODE")) {
        assert_screen "firefox-confirm-fips_enabled";
    }
    else {
        assert_screen "firefox-device-manager_fips-kernel-mode";
    }

    # Quit Firefox and back to desktop
    quit_firefox;
    assert_screen "generic-desktop";
}

sub test_flags {
    return {fatal => 0};
}

1;
