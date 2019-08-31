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
        last unless check_screen("opensuse-welcome-show-on-boot");
        die "Unable to untick 'Show on next startup'" if $retry == 5;
    }

    # Close welcome screen - (Retries may be needed: poo#56024)
    for my $retry (1 .. 5) {
        assert_and_click_until_screen_change("opensuse-welcome-close-btn", 5, 5);
        last unless check_screen("opensuse-welcome");
        die "Unable to close openSUSE Welcome screen" if $retry == 5;
    }
}

1;
