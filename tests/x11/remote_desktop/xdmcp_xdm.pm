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
# Summary: Remote Login: XDMCP with xdm and icewm configured
# Maintainer: Chingkai <qkzhu@suse.com>
# Tags: tc#1586204

use strict;
use warnings;
use base 'x11test';
use testapi;
use lockapi;
use version_utils 'is_sle';

sub run {
    my ($self) = @_;

    # Wait for supportserver if not yet ready
    mutex_lock 'dhcp';
    mutex_unlock 'dhcp';
    mutex_lock 'xdmcp';

    # Make sure the client gets the IP address and configure the firewall
    x11_start_program('xterm');
    become_root;
    assert_script_run 'dhclient';
    $self->configure_xdmcp_firewall;
    type_string "exit\n";

    # Remote access SLES via Xephyr
    type_string "Xephyr -query 10.0.2.1 -terminate :1\n";
    assert_screen 'xdmcp-xdm', 90;
    type_string "$username\n";
    wait_still_screen 3;
    type_password;
    send_key 'ret';
    assert_screen 'xdmcp-icewm-generic-desktop';
    send_key 'alt-f4';    # Close Xephyr
    wait_still_screen 3;
    send_key 'alt-f4';    # Close xterm

    mutex_unlock 'xdmcp';
}

1;
