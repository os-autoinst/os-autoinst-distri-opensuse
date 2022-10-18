# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test '# setenforce/getenforce' commands work
#          # setenforce - modify the mode SELinux is running in
#          #   - usage:  setenforce [ Enforcing | Permissive | 1 | 0 ]
#          # getenforce - reports whether SELinux is enforcing, permissive, or disabled
# Maintainer: QE Security <none@suse.de>
# Tags: poo#105202, tc#1769801

use base 'opensusebasetest';
use power_action_utils "power_action";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use Utils::Backends 'is_pvm';

sub run {
    my ($self) = @_;
    my $mode_old = 'Enforcing';
    my $mode_new = 'Permissive';

    select_serial_terminal;

    # Get the current SELinux policy mode
    $mode_old = script_output('getenforce');

    # Set to 'Permissive' mode
    $mode_new = 'Permissive';
    assert_script_run("setenforce $mode_new");
    assert_script_run('setenforce 0');
    validate_script_output('getenforce', sub { m/$mode_new/ });

    # Reboot
    power_action("reboot", textmode => 1);
    reconnect_mgmt_console if is_pvm;
    $self->wait_boot(textmode => 1, ready_time => 600, bootloader_time => 300);
    select_serial_terminal;

    # Check the mode after reboot, the mode returns to original one
    validate_script_output('getenforce', sub { m/$mode_old/ });

    # Set to 'Enforcing' mode
    $mode_new = 'Enforcing';
    assert_script_run("setenforce $mode_new");
    assert_script_run('setenforce 1');
    validate_script_output('getenforce', sub { m/$mode_new/ });

    # Reboot
    power_action("reboot", textmode => 1);
    reconnect_mgmt_console if is_pvm;
    $self->wait_boot(textmode => 1, ready_time => 600, bootloader_time => 300);
    select_serial_terminal;

    # Check the mode after reboot, the mode returns to original one
    validate_script_output('getenforce', sub { m/$mode_old/ });
}

1;
