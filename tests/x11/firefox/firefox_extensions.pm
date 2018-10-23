# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Case#1479189: Firefox: Add-ons - Extensions
# Maintainer: wnereiz <wnereiz@gmail.com>

use strict;
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
    assert_and_click "firefox-searchall-addon";
    type_string "flagfox\n";
    if (is_sle('=12-sp4')) {
        assert_and_click('firefox-extensions-flagfox', 'right');
        assert_and_click('firefox-extensions-flagfox_install');
    }
    else {
        assert_and_click('firefox-extensions-flagfox');
        assert_and_click('firefox-extensions-add-to-firefox');
        assert_and_click('firefox-extensions-confirm-add');
        # close the flagfox relase notes tab
        wait_still_screen 3;
        save_screenshot;
        send_key 'ctrl-w';
        # close the flagfox search tab
        send_key 'ctrl-w';
    }
    # refresh the page to see addon buttons
    send_key 'f5' unless is_sle('=12-sp4');
    assert_screen('firefox-extensions-flagfox_installed', 90);

    send_key "alt-1";
    $self->firefox_open_url('opensuse.org');
    assert_screen('firefox-extensions-show_flag');

    send_key "alt-2";
    assert_and_click('firefox-extensions-flagfox_installed');

    send_key "alt-1";
    assert_screen('firefox-extensions-no_flag', 90);

    $self->exit_firefox;
}
1;
