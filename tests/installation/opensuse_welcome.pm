# SUSE's openQA tests
#
# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: openSUSE Welcome should auto-launch on GNOME/KDE/XFCE Sessions
#          Disable auto-launch on next boot and close application
# Maintainer: Dominique Leuenberger <dimstar@suse.de>

use Mojo::Base 'x11test';
use testapi;
use utils;
use x11utils qw(handle_welcome_screen turn_off_plasma_tooltips update_x11_vt);
use version_utils qw(is_upgrade is_leap);

sub run {
    my @tags = qw(generic-desktop opensuse-welcome);
    push(@tags, qw(gnome-activities opensuse-welcome-gnome40-activities)) if check_var('DESKTOP', 'gnome');
    assert_screen \@tags;
    if (is_upgrade) {
        # In case of upgrade scenario, check if opensuse_welcome window has been already deactivated from startup
        if (match_has_tag('opensuse-welcome') || match_has_tag('opensuse-welcome-gnome40-activities')) {
            handle_welcome_screen;
        }
    } else {
        if (match_has_tag('generic-desktop') && is_leap('=16.0')) {
            record_soft_failure("bsc#1252847");
        } else {
            handle_welcome_screen;
        }
    }

    if (check_var('DESKTOP', 'kde')) {
        turn_off_plasma_tooltips;
        update_x11_vt;
    }
}

sub test_flags {
    return {milestone => 1};
}

# 'generic-desktop' already checked in wait_boot_past_bootloader
sub post_run_hook { }

1;
