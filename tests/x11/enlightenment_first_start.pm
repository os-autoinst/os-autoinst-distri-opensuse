# SUSE's openQA tests
#
# Copyright 2012-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: enlightenment
# Summary: Other Desktop Environments: Enlightenment
# Maintainer: Dominique Leuenberger <dimstar@opensuse.org>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;
use Utils::Architectures;

sub run {
    mouse_hide();
    assert_screen [qw(enlightenment_keyboard_english enlightenment_language_english)];
    if (match_has_tag 'enlightenment_language_english') {
        record_soft_failure('bsc#1076835 - Enlightenment: newly asks for language');
        assert_and_click "enlightenment_language_english";
        assert_and_click "enlightenment_assistant_next";
    }
    assert_and_click "enlightenment_keyboard_english";
    assert_and_click "enlightenment_assistant_next";
    assert_and_click "enlightenment_profile_selection";
    assert_and_click "enlightenment_assistant_next";
    assert_and_click "enlightenment_profile_size";
    assert_and_click "enlightenment_assistant_next";
    assert_screen "enlightenment_windowfocus";
    assert_and_click "enlightenment_assistant_next";
    assert_screen [qw(enlightenment_keybindings enlightenment_bluez_not_found)];
    if (match_has_tag 'enlightenment_keybindings') {
        assert_and_click "enlightenment_assistant_next";
        assert_screen [qw(enlightenment_compositing enlightenment_bluez_not_found)];
    }
    if (match_has_tag 'enlightenment_bluez_not_found') {
        assert_and_click 'enlightenment_assistant_next';
        assert_screen 'enlightenment_compositing';
    }
    assert_and_click "enlightenment_assistant_next";
    if (get_required_var('ARCH') =~ /86/ || is_aarch64 || is_arm) {
        my $retry = 0;
        while ($retry < 5) {
            assert_screen [qw(enlightenment_generic_desktop enlightenment_acpid_missing)];
            click_lastmatch if match_has_tag 'enlightenment_acpid_missing';
            last if match_has_tag 'enlightenment_generic_desktop';
            $retry++;
        }
    }
    assert_screen 'enlightenment_generic_desktop';
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
