# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Ensure screensaver is working and then disable it
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base "x11test";
use strict;
use warnings;
use testapi;
use x11utils;

sub run {
    my ($self) = @_;

    select_console 'x11';
    ensure_unlocked_desktop;
    assert_screen "generic-desktop";

    # set screensaver timeout to one minute
    set_screensaver_timeout(1);

    # wait for screensaver to start
    assert_screen [qw(screenlock screenlock-password)], 70;
    ensure_unlocked_desktop;
    mouse_hide(1);

    turn_off_screensaver;

    # ensure that the screensaver will not start anymore
    sleep 70;
    assert_screen "generic-desktop";
}

1;
