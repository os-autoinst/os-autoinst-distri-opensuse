# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: setup pidgin test cases; startup main window and check basic
#   account status
# Maintainer: Chingkai <chuchingkai@gmail.com>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_sle is_tumbleweed);

sub run {
    mouse_hide(1);
    ensure_installed('pidgin');

    # Enable the showoffline
    x11_start_program('pidgin');
    send_key "alt-c";

    # pidgin main window is hidden in tray at first run
    # need to show up the main window (12-SP2 and SP3)
    # the main window is shown correctly in SLE15
    if (is_sle('>=15') or is_tumbleweed) {
        wait_still_screen;
    }
    else {
        hold_key "ctrl-alt";
        send_key "tab";
        wait_still_screen;
        send_key "tab";
        wait_still_screen;
        send_key "tab";
        assert_screen "status-icons";
        release_key "ctrl-alt";
        assert_and_click "status-icons-pidgin";
    }

    # check showoffline status is off
    send_key "alt-b";
    wait_still_screen;
    send_key "o";
    assert_screen "pidgin-showoffline-off";
    # enable showoffline
    send_key "o";
    wait_still_screen;
    # check showoffline status is on
    send_key "alt-b";
    wait_still_screen;
    send_key "o";
    assert_screen "pidgin-showoffline-on";
    send_key "esc";

    send_key "ctrl-q";    # quit pidgin
}

# add milestone flag to save pidgin installation in lastgood vm snapshot
sub test_flags {
    return {milestone => 1};
}

1;
