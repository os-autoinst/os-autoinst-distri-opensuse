# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: log out, check lightdm-gtk-greeter and log in again
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "x11test";
use strict;
use warnings;
use testapi;

sub run {
    x11_start_program('xfce4-session-logout', target_match => 'logoutdialog');
    send_key "alt-l";
    assert_screen 'test-xfce_lightdm_logout_login-1';
    type_password;
    send_key "ret";
    assert_screen 'generic-desktop', 100;
    mouse_set(100, 100);
    for (1 .. 4) {
        mouse_hide;
        check_screen('mouse-cursor', 1) || return;
    }
    die "mouse cursor still visible";
}

1;
