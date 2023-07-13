# Copyright 2017-2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: tigervnc gnome-terminal nautilus
# Summary: Remote Login: One-time VNC Session with tigervnc and xvnc
# Maintainer: Grace Wang <grace.wang@suse.com>
# Tags: tc#1586206

use strict;
use warnings;
use base 'basetest';
use testapi;
use lockapi;
use x11utils 'handle_login';

sub run {
    #wait for supportserver if not yet ready
    mutex_lock 'dhcp';
    mutex_unlock 'dhcp';
    mutex_lock 'xvnc';

    # Start vncviewer and login with fullscreen
    x11_start_program('vncviewer', target_match => 'vnc_password_dialog');
    type_string '10.0.2.1:1';
    wait_still_screen 3;
    assert_and_click 'vncviewer-options';
    assert_and_click 'vncviewer-options-screen';
    assert_and_click 'vncviewer-options-fullscreen';
    assert_and_click 'vncviewer-options-security';
    assert_and_click 'vncviewer-options-tlsx509';
    assert_and_click 'vncviewer-options-ok';
    wait_still_screen 3;
    send_key 'ret';
    handle_login;

    # Launch gnome-terminal and nautilus remotely
    x11_start_program('gnome-terminal');
    send_key 'alt-f4';
    send_key 'ret';
    wait_still_screen 3;
    x11_start_program('nautilus');
    send_key 'alt-f4';

    # Exit vncviewer
    send_key 'f8';
    assert_screen 'vncviewer-menu';
    assert_and_click 'vncviewer-menu-exit';

    mutex_unlock 'xvnc';
}

1;
