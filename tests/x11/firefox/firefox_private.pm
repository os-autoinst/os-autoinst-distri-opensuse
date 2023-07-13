# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: MozillaFirefox
# Summary: Case#1479412: Firefox: Private Browsing
# - Launch xterm, kill firefox, cleanup previous firefox configuration, launch
# firefox
# - Open private browsing
#   - Open "facebook.com" and check
# - Restart firefox
# - Open history
# - Select "Today"
# - Check that facebook is not recorded
# - Close history and firefox
# Maintainer: wnereiz <wnereiz@gmail.com>

use strict;
use warnings;
use base "x11test";
use testapi;

sub run {
    my ($self) = @_;
    $self->start_firefox_with_profile;

    wait_still_screen 1;
    send_key "ctrl-shift-p";
    assert_screen 'firefox-private-browsing';
    $self->firefox_open_url('facebook.com', assert_loaded_url => 'firefox-private-facebook');
    $self->restart_firefox;

    send_key "ctrl-h";
    assert_and_click('firefox-private-checktoday');
    assert_screen('firefox-private-checkhistory', 60);
    send_key "ctrl-h";

    # Exit
    $self->exit_firefox;
}
1;
