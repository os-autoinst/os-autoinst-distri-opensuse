# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Boot windows image for the first time and provide basic user environment configuration
# Maintainer: Ludwig Nussel <ludwig.nussel@suse.de>

use base "windowsbasetest";
use strict;
use warnings;
use testapi;

sub run {
    my $self = shift;

    assert_screen 'windows-start-with-region', 360;
    assert_and_click 'windows-yes';
    assert_screen 'windows-keyboard-layout-page',                    180;
    send_key_until_needlematch 'windows-keyboard-layout-english-us', 'down';
    assert_and_click 'windows-yes';
    assert_screen 'windows-second-keyboard';
    assert_and_click 'windows-skip-second-keyboard';
    # Network setup takes ages
    assert_screen 'windows-account-setup', 360;
    assert_and_click 'windows-select-personal-use', dclick => 1;
    wait_still_screen stilltime => 2, timeout => 10, similarity_level => 43;
    assert_and_click 'windows-next';
    assert_screen 'windows-signin-with-ms';
    assert_and_click 'windows-offline';
    wait_still_screen stilltime => 2, timeout => 10, similarity_level => 43;
    assert_and_click 'windows-limited-exp', timeout => 60;
    wait_still_screen stilltime => 2, timeout => 10, similarity_level => 43;
    assert_and_click 'windows-create-account';
    wait_still_screen stilltime => 2, timeout => 10, similarity_level => 43;
    type_string $realname;    # input account name
    wait_still_screen stilltime => 2, timeout => 10, similarity_level => 43;
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

    foreach my $tag (qw(
        windows-dont-use-speech-recognition
        windows-turn-off-find-device
        windows-dont-improve-inking&typing
        windows-dont-user-my-location
        windows-send-full-diagnostic-data
        )) {
        assert_and_click $tag;
        wait_still_screen stilltime => 2, timeout => 10, similarity_level => 43;
    }

    send_key 'pgdn';
    assert_and_click 'windows-dont-get-tailored-experiences';
    assert_and_click 'windows-dont-use-adID';
    assert_and_click 'windows-accept';

    assert_screen 'windows-enable-more-devices';
    assert_and_click 'windows-no';
    assert_screen 'windows-make-cortana-personal-assistant';
    assert_and_click 'windows-accept';

    assert_screen([qw(windows-desktop windows-first-boot networks-popup-be-discoverable)], 600);

    if (match_has_tag 'network-popup-be-discoverable') {
        assert_and_click 'network-discover-yes';
        wait_screen_change(sub { send_key 'ret' }, 10);
    }

    # setup stable lock screen background
    $self->use_search_feature('lock screen settings');
    assert_screen 'lock-screen-in-search';
    wait_still_screen stilltime => 2, timeout => 10, similarity_level => 43;
    assert_and_click 'lock-screen-in-search', dclick => 1;
    assert_screen 'lock-screen-settings';
    assert_and_click 'lock-screen-background';
    assert_and_click 'select-picture';

    # turn off hibernation and fast startup
    $self->open_powershell_as_admin;
    $self->run_in_powershell(cmd => q{REG ADD "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d "0" /f});
    $self->run_in_powershell(cmd => 'powercfg /hibernate off');

    # poweroff
    $self->reboot_or_shutdown();
}

1;
