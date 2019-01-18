# Copyright (C) 2017 SUSE LLC
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
# Summary: Remote Login: One-time VNC Session failed due to a previous graphical session
# Maintainer: Chingkai <qkzhu@suse.com>
# Tags: tc#1586208

use strict;
use warnings;
use base 'basetest';
use testapi;
use lockapi;
use utils;

sub start_vncviewer {
    x11_start_program('vncviewer 10.0.2.1:1 -Fullscreen -SecurityTypes None', target_match => [qw(displaymanager vnc_certificate_warning)]);
    if (match_has_tag 'vnc_certificate_warning') {
        send_key 'ret';
        assert_screen [qw(displaymanager vnc_certificate_warning-2)];
        if (match_has_tag 'vnc_certificate_warning-2') {
            send_key 'ret';
        }
    }
}

sub run {
    my $self = shift;

    #wait for supportserver if not yet ready
    mutex_lock 'dhcp';
    mutex_unlock 'dhcp';
    mutex_lock 'xvnc';

    # Make sure the client gets the IP address
    x11_start_program('xterm');
    become_root;
    assert_script_run 'dhclient';
    type_string "exit\n";
    wait_screen_change { send_key 'alt-f4'; };

    # Setup the first remote connection and minimize the vncviewer
    $self->start_vncviewer;
    handle_login;
    assert_screen 'generic-desktop';
    send_key 'f8';
    assert_screen 'vncviewer-menu';
    send_key 'z';

    # Login to the non-shared session by using another vncviewer
    $self->start_vncviewer;
    handle_login;
    assert_screen 'xvnc-multilogin-refused';
    send_key 'f8';
    assert_screen 'vncviewer-menu';
    send_key 'x';

    # Exit the minimized session
    hold_key 'alt';
    send_key_until_needlematch('vncviewer-minimize', 'tab');
    release_key 'alt';
    assert_screen 'generic-desktop';
    send_key 'f8';
    assert_screen 'vncviewer-menu';
    send_key 'x';

    mutex_unlock 'xvnc';
}

1;
