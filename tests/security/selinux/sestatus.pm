# Copyright (C) 2018-2021 SUSE LLC
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
use warnings;
use testapi;
use utils;
use Utils::Backends 'is_pvm';

sub run {
    my ($self) = @_;
    my $selinux_config_file = "/etc/selinux/config";
    select_console "root-console";

    # SELinux by default
    validate_script_output("sestatus", sub { m/SELinux status: .*disabled/ });

    # workaround for "selinux-auto-relabel" in case: auto relabel then trigger reboot
    assert_script_run("sed -ie \'s/GRUB_TIMEOUT.*/GRUB_TIMEOUT=8/\' /etc/default/grub");

    # enable SELinux in grub
    add_grub_cmdline_settings('security=selinux selinux=1 enforcing=0', update_grub => 1);

    # control (enable) the status of SELinux on the system
    assert_script_run("sed -i -e 's/^SELINUX=/#SELINUX=/' $selinux_config_file");
    assert_script_run("echo 'SELINUX=permissive' >> $selinux_config_file");

    # set SELINUXTYPE=minimum
    assert_script_run("sed -i -e 's/^SELINUXTYPE=/#SELINUXTYPE=/' $selinux_config_file");
    assert_script_run("echo 'SELINUXTYPE=minimum' >> $selinux_config_file");
    assert_script_run("systemctl enable auditd");


    # reboot the vm and reconnect the console
    power_action("reboot", textmode => 1);
    reconnect_mgmt_console if is_pvm;
    $self->wait_boot(textmode => 1, ready_time => 600, bootloader_time => 300);
    select_console "root-console";

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
