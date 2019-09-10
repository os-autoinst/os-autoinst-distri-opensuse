# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: openSUSE Welcome should auto-launch on GNOME/KDE/XFCE Sessions
#          Disable auto-launch on next boot and close application
# Maintainer: Dominique Leuenberger <dimstar@suse.de>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    assert_screen("opensuse-welcome");

    # Untick box - (Retries may be needed: poo#56024)
    for my $retry (1 .. 5) {
        assert_and_click_until_screen_change("opensuse-welcome-show-on-boot", 5, 5);
        # Moving the cursor already causes screen changes - do not fail the check
        # immediately but allow some time to reach the final state
        last if check_screen("opensuse-welcome-show-on-boot-unselected", timeout => 5);
        die "Unable to untick 'Show on next startup'" if $retry == 5;
    }

    for my $retry (1 .. 5) {
        wait_screen_change { send_key 'alt-f4' };
        last unless check_screen("opensuse-welcome", timeout => 2);
        die "Unable to close openSUSE Welcome screen" if $retry == 5;
    }
}

sub test_flags {
    return {milestone => 1};
}

1;
