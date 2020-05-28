# SUSE's openQA tests
#
# Copyright © 2019-2020 SUSE LLC
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
use x11utils 'handle_welcome_screen';

sub run {
    handle_welcome_screen;
}

sub test_flags {
    return {milestone => 1};
}

# 'generic-desktop' already checked in wait_boot_past_bootloader
sub post_run_hook { }

1;
