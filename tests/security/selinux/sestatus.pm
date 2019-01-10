# Copyright (C) 2018-2019 SUSE LLC
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
# Summary: Test "sestatus" command gets the right status of a system running SELinux
# Maintainer: llzhao <llzhao@suse.com>
# Tags: poo#40358, tc#1682592

use base 'opensusebasetest';
use power_action_utils "power_action";
use bootloader_setup 'add_grub_cmdline_settings';
use strict;
use testapi;
use utils;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    # SELinux by default
    validate_script_output("sestatus", sub { m/SELinux status: .*disabled/ });

    # enable SELinux in grub
    add_grub_cmdline_settings('security=selinux selinux=1 enforcing=0', 1);

    power_action("reboot", textmode => 1);
    $self->wait_boot;
    $self->select_serial_terminal;

    validate_script_output(
        "sestatus",
        sub {
            m/
            SELinux\ status:\ .*enabled.*
            SELinuxfs\ mount:\ .*\/sys\/fs\/selinux.*
            SELinux\ root\ directory:\ .*\/etc\/selinux.*
            Loaded\ policy\ name:\ .*minimum.*
            Current\ mode:\ .*permissive.*
            Mode\ from\ config\ file:\ .*permissive.*
            Policy\ MLS\ status:\ .*enabled.*
            Policy\ deny_unknown\ status:\ .*allowed.*
            Max\ kernel\ policy\ version:\ .*[0-9]+.*/sx
        });
}

1;
