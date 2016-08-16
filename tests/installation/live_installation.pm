# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "installbasetest";
use testapi;
use strict;

sub send_key_and_wait {
    my ($key, $wait_time) = @_;
    $wait_time //= 1;
    send_key $key;
    wait_still_screen($wait_time);
}

sub run() {
    assert_and_click 'live-installation';
    assert_and_click 'maximize';
    mouse_hide;
    wait_still_screen;
    # To fully reuse installer screenshots we set to fullscreen. Unfortunately
    # it seems no default shortcut is configured in plasma but we can use the
    # window context menu.
    send_key 'alt-f3';
    assert_screen 'context-menu-more_actions';
    # more
    send_key_and_wait 'alt-m';
    # fullscreen
    send_key_and_wait 'alt-f';
    assert_screen 'fullscreen-mode-information_dialog', 180;
    send_key 'ret';
    save_screenshot;
}

1;
