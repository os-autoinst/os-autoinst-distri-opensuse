# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Case#1479413: Firefox: Full Screen Browsing

# Package: MozillaFirefox
# Summary: Case#1479413: Firefox: Full Screen Browsing
# - Launch xterm, kill firefox, cleanup previous firefox configuration, launch
# firefox
# - Open "file:///usr/share/w3m/w3mhelp.html" and check
# - Switch firefox to fullscreen mode
# - Switch back to windowed mode
# - Exit firefox
# Maintainer: wnereiz <wnereiz@gmail.com>

use strict;
use warnings;
use base "x11test";
use testapi;

sub run {
    my ($self) = @_;

    $self->start_firefox_with_profile;
    $self->firefox_open_url('file:///usr/share/w3m/w3mhelp.html', assert_loaded_url => 'firefox-fullscreen-page');

    send_key "f11";
    assert_screen('firefox-fullscreen-enter', 90);

    wait_still_screen 2, 4;
    send_key "f11";
    assert_screen('firefox-fullscreen-page', 90);

    $self->exit_firefox;
}
1;
