# SUSE's openQA tests
#
# Copyright SUSE LLC and contributors
# SPDX-License-Identifier: FSFAP

# Summary: Test Aeon first boot and initial setup after installation

# Maintainer: Jan-Willem Harmannij <jwharmannij at gmail com>

use Mojo::Base 'basetest';
use testapi;

sub run {
    # Use the common password as passphrase
    my $encryption_passphrase = $testapi::password;

    # Input the encryption passphrase
    assert_screen 'aeon-boot-enter-passphrase', 600;
    type_string $encryption_passphrase;
    send_key 'ret';

    # Aeon will boot and show a Welcome screen with the language selection
    assert_screen 'aeon-firstboot-language-selection', 600;

    # Select default language and keyboard layout
    assert_and_click 'aeon-firstboot-language-selection';
    assert_and_click 'aeon-firstboot-keyboard-layout';

    # Set timezone
    assert_and_click 'aeon-firstboot-timezone-1';
    # See: <https://gitlab.gnome.org/GNOME/gnome-initial-setup/-/issues/156>
    click_lastmatch(point_id => "search_entry");
    type_string('London, East', wait_screen_change => 6, max_interval => utils::VERY_SLOW_TYPING_SPEED);
    assert_and_click('aeon-firstboot-timezone-2');
    # We need to move focus to the next button, so we use tab and once the
    # button is in focus, then enter to click it.
    send_key 'tab';
    send_key 'tab';
    send_key 'ret';

    # User setup
    assert_screen 'aeon-firstboot-aboutyou';
    type_string $testapi::username;
    send_key 'ret';
    assert_screen 'aeon-firstboot-password-1';
    type_string $testapi::password;
    send_key 'tab';
    send_key 'tab';
    type_string $testapi::password;
    assert_and_click 'aeon-firstboot-password-2';

    # Complete
    assert_and_click 'aeon-firstboot-complete';

    # Wait until the Aeon Welcome message appears
    assert_screen 'aeon-firstboot-applications-1', 600;
    assert_and_click 'aeon-firstboot-applications-1';

    # Click Customize
    assert_and_click 'aeon-firstboot-applications-2';

    # Click OK to start installing the default applications
    assert_and_click 'aeon-firstboot-applications-3';

    # Installing the default applications takes a while.
    # Press 'ctrl' every 60 seconds for 30 minutes to avoid the screen lock.
    send_key_until_needlematch 'aeon-firstboot-done', 'ctrl', 30, 60;

    # Dismiss the final screen
    send_key 'ret';

    wait_still_screen 1;
    save_screenshot;
}

1;
