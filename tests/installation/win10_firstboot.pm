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
    assert_screen 'windows-start-with-region', 1000;
    assert_and_click 'windows-yes';
    assert_screen 'windows-keyboard-layout';
    assert_and_click 'windows-yes';
    assert_and_click 'windows-skip-second-keyboard';
    assert_screen 'windows-signin-with-ms', 1000;
    assert_and_click 'windows-offline';
    assert_and_click 'windows-no-signin-ms-instead';
    sleep 3;
    type_string $realname;    # input account name
    assert_and_click 'windows-next';
    type_password;            # input password
    assert_and_click 'windows-next';
    type_password;            # confirm password
    assert_and_click 'windows-next';
    for (1 .. 3) {
        sleep 3;
        assert_and_click 'windows-security-question';
        send_key 'down';
        send_key 'ret';
        send_key 'tab';
        type_string 'security';
        sleep 3;
        assert_and_click 'windows-next';
    }
    assert_screen 'windows-make-cortana-personal-assistant';
    assert_and_click 'windows-no';
    assert_and_click 'windows-dont-use-speech-recognition';
    assert_and_click 'windows-accept';
    assert_and_click 'windows-dont-user-my-location';
    assert_and_click 'windows-accept';
    assert_and_click 'windows-turn-off-find-device';
    assert_and_click 'windows-accept';
    assert_and_click 'windows-send-full-diagnostic-data';
    assert_and_click 'windows-accept';
    assert_and_click 'windows-dont-improve-inking&typing';
    assert_and_click 'windows-accept';
    assert_and_click 'windows-dont-get-tailored-experiences';
    assert_and_click 'windows-accept';
    assert_and_click 'windows-dont-use-adID';
    assert_and_click 'windows-accept';
    assert_screen 'windows-first-boot', 600;
}

1;
