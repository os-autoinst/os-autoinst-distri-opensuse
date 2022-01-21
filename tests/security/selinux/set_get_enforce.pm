# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test "# setenforce/getenforce" commands work
#          # setenforce - modify the mode SELinux is running in
#          #   usage:  setenforce [ Enforcing | Permissive | 1 | 0 ]
#          # getenforce - reports whether SELinux is enforcing, permissive, or disabled.
# Maintainer: llzhao <llzhao@suse.com>
# Tags: poo#105202, tc#1769801

use base 'opensusebasetest';
use power_action_utils "power_action";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = @_;

    $self->select_serial_terminal;

    # Set to 'Permissive' mode
    assert_script_run('setenforce Permissive');
    validate_script_output("getenforce", sub { m/Permissive/ });

    # Reboot and check
    power_action("reboot", textmode => 1);
    reconnect_mgmt_console if is_pvm;
    $self->wait_boot(textmode => 1, ready_time => 600, bootloader_time => 300);
    $self->select_serial_terminal;
    validate_script_output("getenforce", sub { m/Permissive/ });

    # Set to 'Enforcing' mode
    assert_script_run('setenforce Enforcing');

    # Reboot and check again
    power_action("reboot", textmode => 1);
    $self->wait_boot(textmode => 1, ready_time => 600, bootloader_time => 300);
    $self->select_serial_terminal;

    validate_script_output("getenforce", sub { m/Enforcing/ });
}

1;
