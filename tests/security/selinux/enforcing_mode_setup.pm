# Copyright 2020-2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Setup OS with enforcing mode for follow-up selinux tool testing
# Maintainer: QE Security <none@suse.de>
# Tags: poo#64538, tc#1745335

use base 'opensusebasetest';
use power_action_utils "power_action";
use bootloader_setup 'replace_grub_cmdline_settings';
use strict;
use warnings;
use testapi;
use utils;
use Utils::Backends 'is_pvm';

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    # make sure SELinux in "permissive" mode
    validate_script_output("sestatus", sub { m/.*Current\ mode:\ .*permissive.*/sx });

    # label system
    assert_script_run("semanage boolean --modify --on selinuxuser_execmod");
    script_run("restorecon -R /", timeout => 1800, die_on_timeout => 0);
    script_run("restorecon -R /*", timeout => 1800, die_on_timeout => 0);

    # enable enforcing mode from SELinux
    replace_grub_cmdline_settings('security=selinux selinux=1 enforcing=0', 'security=selinux selinux=1 enforcing=1', update_grub => 1);

    # control (enable) the status of SELinux on the system
    assert_script_run("sed -i -e 's/^SELINUX=/#SELINUX=/' /etc/selinux/config");
    assert_script_run("echo 'SELINUX=enforcing' >> /etc/selinux/config");

    power_action("reboot", textmode => 1);
    reconnect_mgmt_console if is_pvm;
    $self->wait_boot(textmode => 1, ready_time => 600, bootloader_time => 300);
    $self->select_serial_terminal;

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
