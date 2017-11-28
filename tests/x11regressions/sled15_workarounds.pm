# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: SLED15 workaround fate#324384 Use GNOME Shell session as default
# Maintainer: Chingkai <qkzhu@suse.com>

use base "x11regressiontest";
use strict;
use testapi;
use utils;

sub run {
    # Switch to GNOME Shell so that all desktop cases can be prepared before fate#324384 is done.
    handle_logout;
    assert_and_click 'displaymanager';
    mouse_hide();
    wait_still_screen;
    send_key 'ret';
    # Move the keyboard focus to the gear icon in gdm greeter
    for (1 .. 2) { send_key 'tab'; }
    send_key 'ret';
    # Switch to GNOME Shell session
    send_key 'right';
    send_key 'down';
    send_key 'ret';
    assert_screen 'displaymanager-password-prompt';
    type_password;
    send_key "ret";
    assert_screen 'desktop-gnome-shell';
}

1;
# vim: set sw=4 et:
