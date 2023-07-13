# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: MozillaFirefox
# Summary: Case#1479189: Firefox: Add-ons - Extensions
# - Launch xterm, kill firefox, cleanup previous firefox configuration, launch
# firefox
# - Open firefox addon manager
# - Open extensions
# - Search for "flagfox"
# - Add and confirm extension install
# - Open url "opensuse.org"
# - Press "alt-1" and check for flag
# - Press "alt-2" and check for flag
# - Press "alt-1" and check for flag
# - Exit firefox
# Maintainer: wnereiz <wnereiz@gmail.com>

use strict;
use warnings;
use base "x11test";
use testapi;
use version_utils 'is_sle';
use utils 'assert_and_click_until_screen_change';

sub run {
    my ($self) = @_;
    $self->start_firefox_with_profile;

    assert_screen('firefox-extensions-no_flag', 90);
    wait_still_screen 3;
    send_key "ctrl-shift-a";
    assert_screen('firefox-addons_manager', 90);
    assert_and_click "firefox-extensions";
    assert_and_click 'firefox-searchall-addon';
    enter_cmd "flagfox";
    wait_still_screen 2, 4;
    assert_and_click 'firefox-extensions-flagfox';
    wait_still_screen 3;
    assert_screen [qw(firefox-extensions-add-to-firefox firefox-extensions-flagfox)], timeout => 120;
    if (match_has_tag('firefox-extensions-add-to-firefox')) {
        assert_and_click_until_screen_change('firefox-extensions-add-to-firefox', 5, 5);
    }
    else {
        send_key_until_needlematch 'firefox-extensions-flagfox', 'f5', 6, 5;
        assert_and_click 'firefox-extensions-flagfox', timeout => 60;
        wait_still_screen 3;
        assert_and_click_until_screen_change('firefox-extensions-add-to-firefox', 5, 5);
    }
    wait_still_screen 3;
    assert_and_click 'firefox-extensions-confirm-add', timeout => 60;
    assert_and_click 'firefox-extensions-added', timeout => 60;
    assert_and_click 'firefox-extensions-flagfox-tab', timeout => 60;
    # close the flagfox relase notes tab and flagfox search tab
    send_key_until_needlematch 'firefox-addons-plugins', 'ctrl-w', 4, 3;
    # refresh the page to see addon buttons
    send_key_until_needlematch 'firefox-extensions-flagfox_installed', 'f5', 6, 5;

    send_key "alt-1";
    $self->firefox_open_url('opensuse.org', assert_loaded_url => 'firefox-extensions-show_flag');

    send_key "alt-2";
    wait_still_screen 2, 4;
    assert_and_click('firefox-extensions-menu-icon') if check_screen('firefox-extensions-menu-icon');
    assert_and_click('firefox-extensions-remove');
    wait_still_screen 2, 4;
    send_key 'spc';
    save_screenshot;
    wait_still_screen 2, 4;

    send_key "alt-1";
    assert_screen('firefox-extensions-no_flag', 90);

    $self->exit_firefox;
}
1;
