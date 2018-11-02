# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Case#1479557: Firefox: RSS Button
# Maintainer: wnereiz <wnereiz@gmail.com>

use strict;
use base "x11test";
use testapi;

sub run {
    my ($self) = @_;
    $self->start_firefox_with_profile;

    send_key "alt-v";
    wait_still_screen 3;
    # press ctrl to avoid strange failure when following 't' acts as 'alt-t'
    send_key 'ctrl';
    send_key "t";
    wait_still_screen 3;
    send_key "c";

    assert_and_click("firefox-rss-button", "right");

    send_key "a";
    send_key "ctrl-w";
    assert_screen("firefox-rss-button_disabled", 60);

    $self->firefox_open_url('https://linux.slashdot.org/');
    assert_and_click("slashdot-cookies-agree") if check_screen("slashdot-cookies", 0);
    wait_still_screen;
    assert_and_click "firefox-rss-button_enabled", "left";
    assert_screen("firefox-rss-page", 60);

    # Exit
    $self->exit_firefox;
}
1;
