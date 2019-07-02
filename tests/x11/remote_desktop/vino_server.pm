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
# Summary: Remote Login: vino server for VNC connections
#          server: vino_server.pm
#          client: vino_client.pm
# Maintainer: Chingkai <qkzhu@suse.com>
# Tags: tc#1586210

use strict;
use warnings;
use base 'x11test';
use testapi;
use lockapi;
use mmapi;

sub run {
    my $self = shift;

    # Setup static NETWORK
    $self->configure_static_ip_nm('10.0.2.15/15');

    # Add the firewall port for VNC
    x11_start_program('xterm');
    become_root;
    assert_script_run 'yast2 firewall services add zone=EXT service=service:vnc-server';
    type_string "exit\n";
    wait_screen_change { send_key 'alt-f4' };

    # Activate vino server
    x11_start_program('gnome-control-center sharing', target_match => 'gcc-sharing');
    assert_and_click 'gcc-sharing-on';
    send_key 'alt-s';
    assert_screen 'gcc-screen-sharing';
    assert_and_click 'gcc-screen-sharing-on';
    send_key 'alt-r';
    wait_still_screen 3;
    send_key 'alt-p';
    type_password;
    wait_still_screen 3;
    send_key 'alt-f4';
    assert_screen 'gcc-sharing-activate';

    # The following section opens a terminal to print vino-server log
    # to help debug poo#49811
    x11_start_program('xterm');
    assert_script_run('killall vino-server');
    type_string("/usr/lib/vino/vino-server | tee /tmp/vino-server.log\n");
    send_key 'alt-tab';

    # Notice vino server is ready for remote access
    mutex_create 'vino_server_ready';

    # Wait until vino client finishes remote access
    wait_for_children;

    save_screenshot;
    wait_screen_change { send_key 'alt-f4' };
    wait_screen_change { send_key 'alt-f4' };
}

1;
