# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: MozillaFirefox
# Summary: Firefox Case#1479190: Add-owns - Appearance
# - Launch xterm, kill firefox, cleanup previous firefox configuration, launch
# firefox
# - Open addon manager
# - Select themes
# - Open url "addons.mozilla.org/en-US/firefox/addon/opensuse" and check
# - Install opensuse theme and check
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

    send_key "ctrl-shift-a";
    assert_and_click('firefox-appearance-tabicon');
    assert_screen('firefox-appearance-default', 30);

    $self->firefox_open_url('addons.mozilla.org/en-US/firefox/addon/opensuse');
    assert_screen('firefox-appearance-mozilla_addons');
    for (1 .. 3) {
        assert_and_click 'firefox-appearance-addto';
        if (check_screen("firefox-appearance-addto-permissions_requested", 10)) {
            assert_and_click "firefox-appearance-addto-permissions_requested";
        }
        last if check_screen 'firefox-appearance-installed', 90;
    }
    # on SLE 12 window gets unselected after pop-up is handled
    assert_and_click 'firefox-appearance-mozilla_addons' if is_sle('<15');
    $self->exit_firefox;
}
1;
