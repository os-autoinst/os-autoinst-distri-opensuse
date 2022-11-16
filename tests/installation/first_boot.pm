# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Special handling to get to the desktop the first time after
#          the installation has been completed (either find the desktop after
#          auto-login or handle the login screen to reach the desktop)
# - Wait for login screen
# - Handle displaymanager
# - Handle login screen
# - Check if generic-desktop was reached
# Maintainer: Max Lin <mlin@suse.com>

use strict;
use warnings;
use base 'bootbasetest';
use x11utils 'turn_off_plasma_tooltips';

sub run {
    shift->wait_boot_past_bootloader;
    turn_off_plasma_tooltips;
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

# 'generic-desktop' already checked in wait_boot_past_bootloader
sub post_run_hook { }

1;
