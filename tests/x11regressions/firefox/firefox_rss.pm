# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Case#1479557: Firefox: RSS Button
# Maintainer: wnereiz <wnereiz@gmail.com>

use strict;
use base "x11regressiontest";
use testapi;

sub run {
    my ($self) = @_;
    $self->start_firefox;

    send_key "alt-v";
    wait_still_screen 3;
    send_key "t";
    wait_still_screen 3;
    send_key "c";

    assert_and_click "firefox-rss-close_hint";
    send_key "alt-f10";
    wait_still_screen 3;
    assert_and_click("firefox-rss-button", "right");

    send_key "a";
    send_key "ctrl-w";
    assert_screen("firefox-rss-button_disabled", 60);

    send_key "esc";
    send_key "alt-d";
    type_string "https://linux.slashdot.org/\n";

    assert_and_click "firefox-rss-button_enabled", "left", 30;
    assert_screen("firefox-rss-page", 60);

    # Exit
    $self->exit_firefox;
}
1;
# vim: set sw=4 et:
