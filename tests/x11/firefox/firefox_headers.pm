# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: MozillaFirefox
# Summary: Test firefox HTTP headers (Case#1436066)
# - Launch xterm, kill firefox, cleanup previous firefox configuration, launch
# firefox
# - Open network monitor tab in developer tools
# - Open url "gnu.org" and check
# - Select HTML and check
# - Select Other and check
# - Refresh page
# - Select "gnu.org", press "shift-F10" and select "Edit and resend" and check
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

    # open network monitor tab in developer tools
    send_key 'ctrl-shift-e';
    assert_screen 'firefox-headers-inspector';
    $self->firefox_open_url('gnu.org', assert_loaded_url => 'firefox-headers-website');

    assert_and_click('firefox-headers-select-html');
    # to see new request window after edit and resend on SLE15
    assert_and_click('firefox-headers-select-other');
    # refresh page
    send_key 'f5';
    wait_still_screen 3;
    assert_screen 'firefox-url-loaded';
    assert_and_click('firefox-headers-select-gnu.org');
    # click into the area so we can scrool down
    assert_and_click('firefox-headers-first_item');
    send_key_until_needlematch('firefox-headers-user_agent', 'down', 30);

    # Exit
    $self->exit_firefox;
}
1;
