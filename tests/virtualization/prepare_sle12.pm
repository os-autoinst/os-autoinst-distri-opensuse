# Copyright (C) 2014 SUSE Linux GmbH
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
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use base "basetest";
use strict;
use testapi;
use virtmanager;

sub run {
    my $self = shift;

    # login and preparation of the system
    if (get_var("DESKTOP") =~ /icewm/) {
        send_key "ret";
        assert_screen "SLE12_login", 520;
        type_string "linux";
        send_key "ret", 1;
        type_string $password;
        send_key "ret", 1;
        save_screenshot;
        # install and launch polkit
        x11_start_program("xterm");
        become_root();
        script_run "zypper -n in polkit-gnome";
        # exit root, and be the default user
        type_string "exit\n";
        sleep 1;
        type_string "nohup /usr/lib/polkit-gnome-authentication-agent-1 &";
        send_key "ret";
    }
    else {
        # auto-login has been selected for gnome
        assert_screen "virt-manager_SLE12_desktop", 520;
    }
    x11_start_program("xterm");
    wait_idle;
    become_root;
    script_run("hostname susetest");
    script_run("echo susetest > /etc/hostname");
    wait_idle;

    send_key "alt-f4";
    # do the update
    #    type_string ("mkdir /mnt/install && mount 10.0.1.99:/volume1/install /mnt/install\n");
    #    wait_idle;
    #    type_string ("zypper addrepo /mnt/install/suse/sle12sp1/suse/ sle12sp1\n");
    #    wait_idle;
    #    type_string ("zypper refresh\n");
    #    wait_idle;
    #    type_string ("zypper -n up --replacefiles\n");
    #    wait_idle;
    #   type_string ("reboot\n");
    #    save_screenshot;
    #    assert_screen "virt-manager_SLE12_desktop", 520;
}

sub test_flags {
    return {milestone => 1};
}

1;

# vim: set sw=4 et:
