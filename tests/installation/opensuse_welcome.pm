# SUSE's openQA tests
#
# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

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
    # In case of upgrade scenario, check if opensuse_welcome window has been already deactivated from startup
    if (get_var('UPGRADE')) {
        my @tags = qw(generic-desktop opensuse-welcome);
        push(@tags, qw(gnome-activities opensuse-welcome-gnome40-activities)) if check_var('DESKTOP', 'gnome');
        assert_screen \@tags;
        if (match_has_tag('opensuse-welcome') || match_has_tag('opensuse-welcome-gnome40-activities')) {
            handle_welcome_screen;
        }
    }
}

sub test_flags {
    return {milestone => 1};
}

# 'generic-desktop' already checked in wait_boot_past_bootloader
sub post_run_hook { }

1;
