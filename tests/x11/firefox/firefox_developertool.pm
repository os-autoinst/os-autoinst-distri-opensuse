# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: MozillaFirefox
# Summary: Case#1479522: Firefox: Web Developer Tools
# - Launch xterm, kill firefox, cleanup previous firefox configuration, launch
# firefox
# - Open url "opensuse.org"
# - Open developer tool
# - Select element
# - Select console
# - Exit firefox
# Maintainer: wnereiz <wnereiz@gmail.com>

use strict;
use warnings;
use base "x11test";
use testapi;

sub run {

    my ($self) = @_;
    $self->start_firefox_with_profile;

    $self->firefox_open_url('opensuse.org');
    assert_screen('firefox-developertool-opensuse');
    send_key 'f12';
    assert_screen('firefox-developertool-general', 30);
    assert_and_click "firefox-developertool-click_element";
    assert_screen "firefox-developertool-check_inspector";
    assert_and_click "firefox-developertool-check_element";
    assert_screen("firefox-developertool-element", 30);
    assert_and_click "firefox-developertool-console_button";
    send_key "f5";
    assert_screen("firefox-developertool-console_contents", 30);

    $self->exit_firefox;
}
1;
