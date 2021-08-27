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
# Package: dhcp-client openssh gedit gnome-control-center
# Summary: Remote Login: X11 forwarding over OpenSSH
# Maintainer: Grace Wang <grace.wang@suse.com>
# Tags: tc#1586202

use strict;
use warnings;
use base 'basetest';
use base 'x11test';
use testapi;
use lockapi;
use utils;

sub run {
    my $self = shift;

    # Wait for supportserver if not yet ready
    mutex_lock 'dhcp';
    mutex_unlock 'dhcp';
    mutex_lock 'ssh';
    mutex_unlock 'ssh';

    # Make sure the client gets the IP address
    x11_start_program('xterm');
    become_root;
    assert_script_run 'dhclient';
    enter_cmd "exit";

    # ssh login
    my $str = 'SSH-' . time;
    enter_cmd "ssh -X root\@10.0.2.1";
    assert_screen 'ssh-login', 60;
    enter_cmd "yes";
    assert_screen 'password-prompt', 60;
    enter_cmd "$password";
    assert_screen 'ssh-login-ok';

    $self->set_standard_prompt();
    $self->enter_test_text('ssh-X-forwarding', cmd => 1);
    assert_screen 'test-sshxterm-1';

    # Launch gedit and gnome control center remotely
    enter_cmd "gedit /etc/issue";
    assert_screen 'x11-forwarding-gedit';
    send_key 'alt-f4';
    wait_still_screen 3;
    enter_cmd "gnome-control-center info";
    assert_screen 'x11-forwarding-gccinfo';
    send_key 'alt-f4';
    wait_still_screen 3;
    enter_cmd "exit";    # Exit the ssh login
    send_key 'alt-f4';
    assert_screen 'generic-desktop';
}

1;
