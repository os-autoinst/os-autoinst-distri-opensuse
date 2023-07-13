# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: MozillaFirefox
# Summary: Firefox Case#1479190: Add-ons - Appearance
# - Launch xterm, kill firefox, cleanup previous firefox configuration, launch
# firefox
# - Open addon manager
# - Select themes
# - Open url "addons.mozilla.org/en-US/firefox/addon/opensuse" and check
# - Install opensuse theme and check
# - Exit firefox
# Maintainer: wnereiz <wnereiz@gmail.com>, QE Core <qe-core@suse.de>

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

    $self->firefox_open_url('addons.mozilla.org/en-US/firefox/addon/opensuse', assert_loaded_url => 'firefox-appearance-mozilla_addons');
    assert_and_click('firefox-appearance-addto');
    wait_still_screen 2, 4;
    assert_and_click('firefox-appearance-addto-permissions_requested');
    assert_screen 'firefox-appearance-installed', 120;
    # on SLE 12 window gets unselected after pop-up is handled
    assert_and_click 'firefox-appearance-mozilla_addons' if is_sle('<15');
    $self->exit_firefox;
}
1;
