# Copyright (C) 2014-2017 SUSE LLC
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

# Summary: Prepare a SLE system for use as a hypervisor host
# Maintainer: aginies <aginies@suse.com>

use base 'basetest';
use strict;
use warnings;
use testapi;
use virtmanager;
use utils 'zypper_call';

sub run {
    my ($self) = @_;
    # login and preparation of the system
    if (get_var('DESKTOP') =~ /icewm/) {
        send_key 'ret';
        assert_screen 'linux-login', 600;
        type_string 'bernhard';
        wait_screen_change { send_key 'ret' };
        type_string $password;
        send_key 'ret';
        save_screenshot;
        # install and launch polkit
        x11_start_program('xterm');
        become_root();
        zypper_call('in polkit-gnome');
        # exit root, and be the default user
        wait_screen_change { type_string "exit\n" };
        type_string 'nohup /usr/lib/polkit-gnome-authentication-agent-1 &';
        send_key 'ret';
    }
    else {
        # auto-login has been selected for gnome
        assert_screen 'generic-desktop', 600;
    }
    x11_start_program('xterm');
    become_root;
    assert_script_run('hostname susetest');
    assert_script_run('echo susetest > /etc/hostname');
    send_key 'alt-f4';
}

sub test_flags {
    return {milestone => 1};
}

1;

