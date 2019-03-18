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
# Summary: Remote Login: client for VNC connections with vino
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
    $self->configure_static_ip_nm('10.0.2.16/15');

    # Wait until target becomes ready
    mutex_lock 'vino_server_ready';

    # Login to the sharing session using vinagre via vino server
    x11_start_program('vinagre', target_match => 'vinagre-launched');
    assert_and_click 'vinagre-enable-shortcut1';
    assert_and_click 'vinagre-enable-shortcut2';
    send_key 'alt-f10';
    assert_screen 'vinagre-launched-maxwindow';
    send_key 'ctrl-n';
    send_key_until_needlematch 'vinagre-protocol-vnc', 'down';
    assert_and_click 'vinagre-connect-host';
    type_string '10.0.2.15';
    wait_still_screen 3;
    send_key 'ret';
    assert_screen 'vinagre-auth', 60;
    type_password;
    wait_still_screen 3;
    send_key 'ret';
    assert_screen 'vinagre-gcc-sharing-activate', 120;
    wait_screen_change { send_key 'ctrl-w'; };    # Disconnect vinagre
    wait_screen_change { send_key 'ctrl-q'; };    # Exit vinagre
    save_screenshot;
}

1;
