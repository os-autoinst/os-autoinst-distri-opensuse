# Copyright (C) 2020 SUSE LLC
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
# Summary: Setup OS with enforcing mode for follow-up selinux tool testing
# Maintainer: llzhao <llzhao@suse.com>
# Tags: poo#64538, tc#1745335

use base 'opensusebasetest';
use power_action_utils "power_action";
use bootloader_setup 'replace_grub_cmdline_settings';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = @_;
    select_console "root-console";

    # make sure SELinux in "permissive" mode
    validate_script_output("sestatus", sub { m/.*Current\ mode:\ .*permissive.*/sx });

    # label system
    assert_script_run("semanage boolean --modify --on selinuxuser_execmod");
    script_run("restorecon -R /",  600);
    script_run("restorecon -R /*", 600);

    # enable enforcing mode from SELinux
    replace_grub_cmdline_settings('security=selinux selinux=1 enforcing=0', 'security=selinux selinux=1 enforcing=1', update_grub => 1);

    # control (enable) the status of SELinux on the system
    assert_script_run("sed -i -e 's/^SELINUX=/#SELINUX=/' /etc/selinux/config");
    assert_script_run("echo 'SELINUX=enforcing' >> /etc/selinux/config");

    power_action("reboot", textmode => 1);
    $self->wait_boot;
    select_console "root-console";

    validate_script_output(
        "sestatus",
        sub {
            m/
            SELinux\ status:\ .*enabled.*
            SELinuxfs\ mount:\ .*\/sys\/fs\/selinux.*
            SELinux\ root\ directory:\ .*\/etc\/selinux.*
            Loaded\ policy\ name:\ .*minimum.*
            Current\ mode:\ .*enforcing.*
            Mode\ from\ config\ file:\ .*enforcing.*
            Policy\ MLS\ status:\ .*enabled.*
            Policy\ deny_unknown\ status:\ .*allowed.*
            Max\ kernel\ policy\ version:\ .*[0-9]+.*/sx
        });
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
