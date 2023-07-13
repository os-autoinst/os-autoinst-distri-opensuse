# SUSE's openQA tests
#
# Copyright 2018-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: remmina
# Summary: Remote Login: One-time VNC Session with remmina and xvnc
# Maintainer: Grace Wang <grace.wang@suse.com>
# Tags: tc#1610354

use strict;
use warnings;
use base 'basetest';
use testapi;
use lockapi;
use x11utils 'handle_login';
use version_utils 'is_sle';

sub run {
    #wait for supportserver if not yet ready
    mutex_lock 'dhcp';
    mutex_unlock 'dhcp';
    mutex_lock 'xvnc';

    # Start Remmina and login the remote server
    x11_start_program('remmina', target_match => 'remmina-launched');
    # The remmmina news turned off screen appears since the remmina got updated in 15SP3
    if (is_sle('15-SP3+')) {
        assert_screen("remmina-news-turned-off", 60);
        assert_and_click("remmina-close-news-turned-off");
    }

    # The default host key is right Ctrl which is not supported by openQA
    # Change the host key to 'z'
    send_key 'ctrl-p';
    assert_screen 'remmina-preferences';
    assert_and_click 'remmina-preferences-keyboard';
    assert_and_click 'remmina-preferences-hostkey';
    assert_screen 'remmina-hostkey-setting';
    send_key 'z';
    assert_screen 'remmina-hostkey-configured';
    send_key 'esc';

    # Add a new VNC connection
    assert_and_click 'remmina-plus-button';
    assert_and_click 'remmina-protocol';
    assert_and_click 'remmina-protocol-vnc';
    assert_and_click 'remmina-advanced-setting';
    assert_and_click 'remmina-disable-encryption';
    assert_and_click 'remmina-basic-setting';
    assert_and_click 'remmina-server-url';
    type_string '10.0.2.1:1';
    assert_and_click 'remmina-color-depth';
    assert_and_click 'remmina-color-16bpp';
    assert_and_click 'remmina-quality';
    assert_and_click 'remmina-quality-good';
    assert_and_click 'remmina-connect';
    assert_screen 'remmina-connected';

    # Enter the full screen mode
    send_key 'z-f';
    handle_login;

    # Disconnect with the remote server
    send_key 'z-f4';
    assert_screen 'remmina-launched';

    # Quit remmina and clean the preferences file
    send_key 'ctrl-q';
    x11_start_program('rm ~/.config/remmina/remmina.pref', valid => 0);

    mutex_unlock 'xvnc';
}

1;
