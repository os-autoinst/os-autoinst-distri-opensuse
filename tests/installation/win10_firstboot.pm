# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Split Windows 10 test
# Maintainer: Ludwig Nussel <ludwig.nussel@suse.de>

use base "installbasetest";
use strict;
use warnings;

use testapi;

sub run {
    assert_screen 'windows-start-with-region', 360;
    assert_and_click 'windows-yes';
    assert_screen 'windows-keyboard-layout', 180;
    assert_and_click 'windows-yes';
    assert_screen 'windows-second-keyboard';
    assert_and_click 'windows-skip-second-keyboard';
    # Network setup takes ages
    # Coffee time!
    assert_screen 'windows-account-setup', 360;
    assert_and_click 'windows-select-personal-use', dclick => 1;
    wait_still_screen stilltime => 10, timeout => 1, similarity_level => 43;
    assert_and_click 'windows-next';
    assert_screen 'windows-signin-with-ms';
    assert_and_click 'windows-offline';
    wait_still_screen stilltime => 10, timeout => 1, similarity_level => 43;
    assert_and_click 'windows-no-signin-ms-instead', timeout => 60;
    wait_still_screen stilltime => 10, timeout => 1, similarity_level => 43;
    assert_and_click 'windows-create-account';
    wait_still_screen stilltime => 10, timeout => 1, similarity_level => 43;
    type_string $realname;    # input account name
    wait_still_screen stilltime => 10, timeout => 1, similarity_level => 43;
    save_screenshot;
    assert_and_click 'windows-next';
    for (1 .. 2) {
        sleep 3;
        type_password;        # input password
        save_screenshot;
        assert_and_click 'windows-next';
    }
    for (1 .. 3) {
        sleep 3;
        assert_and_click 'windows-security-question';
        send_key 'down';
        send_key 'ret';
        send_key 'tab';
        sleep 1;
        type_string 'security';
        sleep 3;
        assert_and_click 'windows-next';
    }
    assert_screen 'windows-enable-more-devices';
    assert_and_click 'windows-no';
    assert_screen 'windows-make-cortana-personal-assistant';
    assert_and_click 'windows-accept';
    wait_still_screen stilltime => 10, timeout => 1, similarity_level => 43;
    assert_and_click 'windows-dont-use-speech-recognition';
    wait_still_screen stilltime => 10, timeout => 1, similarity_level => 43;
    assert_and_click 'windows-accept';
    wait_still_screen stilltime => 10, timeout => 1, similarity_level => 43;
    assert_and_click 'windows-dont-user-my-location';
    wait_still_screen stilltime => 10, timeout => 1, similarity_level => 43;
    assert_and_click 'windows-accept';
    wait_still_screen stilltime => 10, timeout => 1, similarity_level => 43;
    assert_and_click 'windows-turn-off-find-device';
    wait_still_screen stilltime => 10, timeout => 1, similarity_level => 43;
    assert_and_click 'windows-accept';
    wait_still_screen stilltime => 10, timeout => 1, similarity_level => 43;
    assert_and_click 'windows-send-full-diagnostic-data';
    wait_still_screen stilltime => 10, timeout => 1, similarity_level => 43;
    assert_and_click 'windows-accept';
    wait_still_screen stilltime => 10, timeout => 1, similarity_level => 43;
    assert_and_click 'windows-dont-improve-inking&typing';
    wait_still_screen stilltime => 10, timeout => 1, similarity_level => 43;
    assert_and_click 'windows-accept';
    wait_still_screen stilltime => 10, timeout => 1, similarity_level => 43;
    assert_and_click 'windows-dont-get-tailored-experiences';
    wait_still_screen stilltime => 10, timeout => 1, similarity_level => 43;
    assert_and_click 'windows-accept';
    wait_still_screen stilltime => 10, timeout => 1, similarity_level => 43;
    assert_and_click 'windows-dont-use-adID';
    wait_still_screen stilltime => 10, timeout => 1, similarity_level => 43;
    assert_and_click 'windows-accept';
}

sub test_flags {
    return {fatal => 1};
}

1;
