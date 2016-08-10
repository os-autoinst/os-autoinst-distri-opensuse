# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "x11test";
use strict;
use testapi;

# log out, check lightdm-gtk-greeter and log in again

sub run() {
    my $self = shift;
    x11_start_program("xfce4-session-logout");
    send_key "alt-l";
    assert_screen 'test-xfce_lightdm_logout_login-1', 13;
    type_password;
    send_key "ret";
    assert_screen 'generic-desktop';
    mouse_set(100, 100);
    sleep 1;
    for (1 .. 4) {
        mouse_hide;
        sleep 3;
        check_screen('mouse-cursor', 1) || return;
    }
    die "mouse cursor still visible";
}

sub test_flags() {
    # as long as we don't understand the failure in mouse_hide we should rather not
    # rely on this test. The problem can't be reproduced outside of openqa
    return {important => 0, milestone => 1};
}

1;
# vim: set sw=4 et:
