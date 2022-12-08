# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: xorg-x11-server-extra
# Summary: Remote Login: XDMCP with xdm and icewm configured
# Maintainer: Grace Wang <grace.wang@suse.com>
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
    $self->configure_xdmcp_firewall;
    enter_cmd "exit";

    # Remote access SLES via Xephyr
    enter_cmd "Xephyr -query 10.0.2.1 -terminate :2";
    assert_screen 'xdmcp-xdm', 90;
    enter_cmd "$username";
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
