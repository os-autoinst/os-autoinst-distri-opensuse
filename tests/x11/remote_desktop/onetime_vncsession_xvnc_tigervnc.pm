# Copyright (C) 2017-2019 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.
#
# Summary: Remote Login: One-time VNC Session with tigervnc and xvnc
# Maintainer: Chingkai <qkzhu@suse.com>
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

    # Make sure the client gets the IP address
    x11_start_program('xterm');
    become_root;
    assert_script_run 'dhclient';
    type_string "exit\n";
    send_key 'alt-f4';

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
    assert_screen 'generic-desktop';

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
    send_key 'x';

    mutex_unlock 'xvnc';
}

1;
