# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

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

sub run {
    my ($self) = @_;
    $self->start_firefox_with_profile;

    assert_screen('firefox-extensions-no_flag', 90);
    wait_still_screen 3;
    send_key "ctrl-shift-a";
    assert_screen('firefox-addons_manager', 90);
    assert_and_click "firefox-extensions";
    for (1 .. 5) {
        assert_and_click 'firefox-searchall-addon';
        type_string "flagfox\n";
        assert_and_click 'firefox-extensions-flagfox';
        wait_still_screen 3;
        assert_and_click 'firefox-extensions-add-to-firefox';
        wait_still_screen 3;
        assert_screen 'firefox-extensions-confirm-add';
        send_key 'alt-a';
        wait_still_screen 3;
        assert_and_click 'firefox-extensions-added';
        wait_still_screen 3;
        assert_and_click 'firefox-extensions-flagfox-tab';
        # close the flagfox relase notes tab and flagfox search tab
        send_key_until_needlematch 'firefox-addons-plugins', 'ctrl-w', 3, 3;
        # refresh the page to see addon buttons
        send_key_until_needlematch 'firefox-extensions-flagfox_installed', 'f5', 5, 5;
        last if check_screen 'firefox-extensions-flagfox_installed';
    }

    send_key "alt-1";
    $self->firefox_open_url('opensuse.org');
    assert_screen('firefox-extensions-show_flag');

    send_key "alt-2";
    assert_and_click('firefox-extensions-menu-icon') if check_screen('firefox-extensions-menu-icon');
    assert_and_click('firefox-extensions-flagfox_installed');

    send_key "alt-1";
    assert_screen('firefox-extensions-no_flag', 90);

    $self->exit_firefox;
}
1;
