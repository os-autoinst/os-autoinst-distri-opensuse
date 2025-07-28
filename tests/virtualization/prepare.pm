# Copyright 2014-2017 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Prepare a SLE system for use as a hypervisor host
# Maintainer: aginies <aginies@suse.com>

use base 'basetest';
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
        wait_screen_change { enter_cmd "exit" };
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

