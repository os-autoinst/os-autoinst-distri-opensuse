# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: GNOME MultiWriter - Minimal Test
# Maintainer: Dominique Leuenberger <dimstar@suse.de>>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    x11_start_program('gnome-multi-writer', target_match => [qw(test-gnome-multi-writer-started polkit-unmount-auth-required)]);
    # With GNOME 3.34, elevated permissions using polkit need be confirmed even if root has no password
    assert_and_click('polkit-unmount-auth-required', 1) if (match_has_tag 'polkit-unmount-auth-required');
    assert_screen('test-gnome-multi-writer-started', 2);
    send_key "alt-f4";
}

1;
