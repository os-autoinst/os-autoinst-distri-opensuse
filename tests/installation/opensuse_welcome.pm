# SUSE's openQA tests
#
# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: openSUSE Welcome should auto-launch on GNOME/KDE/XFCE Sessions
#          Disable auto-launch on next boot and close application
# Maintainer: Dominique Leuenberger <dimstar@suse.de>

use base "x11test";
use testapi;
use utils;
use x11utils qw(handle_welcome_screen turn_off_plasma_tooltips);
use version_utils 'is_upgrade';

sub run {
    # In case of upgrade scenario, check if opensuse_welcome window has been already deactivated from startup
    if (is_upgrade) {
        my @tags = qw(generic-desktop opensuse-welcome);
        push(@tags, qw(gnome-activities opensuse-welcome-gnome40-activities)) if check_var('DESKTOP', 'gnome');
        assert_screen \@tags;
        if (match_has_tag('opensuse-welcome') || match_has_tag('opensuse-welcome-gnome40-activities')) {
            handle_welcome_screen;
        }
    } else {
        handle_welcome_screen;
    }

    # Workaround for boo#1211628
    if (check_var('DESKTOP', 'kde') && match_has_tag('boo1211628')) {
        # plasmashell crashed and openSUSE theme is not fully applied
        # Workaround that
        x11_start_program('rm ~/.config/plasma-org.kde.plasma.desktop-appletsrc', valid => 0);
        x11_start_program('konsole', valid => 0);
        x11_start_program('plasmashell --replace', valid => 0);
        x11_start_program('pkill konsole', valid => 0);
        assert_screen 'generic-desktop';
        die 'Workaround for boo#1211628 did not work' if (match_has_tag('boo1211628'));
    }

    turn_off_plasma_tooltips;
}

sub test_flags {
    return {milestone => 1};
}

# 'generic-desktop' already checked in wait_boot_past_bootloader
sub post_run_hook { }

1;
