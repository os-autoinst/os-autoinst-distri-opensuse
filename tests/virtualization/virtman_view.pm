# Copyright 2014-2017 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Package: virt-manager
# Summary: Basic test of virtman features
# Maintainer: Antoine <aginies@suse.com>

use base 'x11test';
use testapi;
use virtmanager;

sub run {
    # enable all view options
    launch_virtmanager();
    # go to preferences
    assert_and_click 'virtman-edit-menu';
    assert_and_click 'virtman-preferences';
    assert_screen 'virtman-preferences-general';
    # go to polling
    wait_screen_change { send_key 'right' };
    for (1 .. 3) { send_key 'tab' }
    assert_screen 'virtman-polling';
    # activate disk I/O
    wait_screen_change { send_key 'spc' };
    send_key 'tab';
    # activate net I/O
    wait_screen_change { send_key 'spc' };
    send_key 'tab';
    # activate Mem stat
    wait_screen_change { send_key 'spc' };
    # close preferences
    send_key 'alt-c';
    # Close stats screen
    send_key 'esc';

    # Make sure we have virt-manager window
    assert_screen 'virt-manager';

    # go to view now
    assert_and_click 'virtman-viewmenu';
    wait_screen_change { send_key 'down' };
    wait_screen_change { send_key 'right' };
    assert_screen 'virtman-viewmenu-graph';
    # activate everything
    for (1 .. 4) {
        send_key 'down';
        wait_screen_change { send_key 'spc' };
    }
    assert_screen 'virtman-viewcheck';
    # close every open windows
    assert_and_click 'virtman-close';
    # close the xterm
    send_key 'alt-f4';
}

1;

