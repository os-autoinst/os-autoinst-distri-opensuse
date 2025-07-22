# SUSE's openQA tests
#
# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: gnome-multi-writer
# Summary: GNOME MultiWriter - Minimal Test
# Maintainer: Dominique Leuenberger <dimstar@suse.de>>

use base "x11test";
use testapi;
use utils;

sub run {
    x11_start_program('gnome-multi-writer', target_match => [qw(test-gnome-multi-writer-started polkit-unmount-auth-required)]);
    # With GNOME 3.34, elevated permissions using polkit need be confirmed even if root has no password
    assert_and_click('polkit-unmount-auth-required', timeout => 1) if (match_has_tag 'polkit-unmount-auth-required');
    assert_screen('test-gnome-multi-writer-started', 2);
    send_key "alt-f4";
}

1;
