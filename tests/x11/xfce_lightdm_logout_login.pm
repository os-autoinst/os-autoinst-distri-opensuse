# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

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
    assert_screen 'generic-desktop';
    mouse_set(100, 100);
    for (1 .. 4) {
        mouse_hide;
        check_screen('mouse-cursor', 1) || return;
    }
    die "mouse cursor still visible";
}

sub test_flags {
    return {milestone => 1};
}

1;
