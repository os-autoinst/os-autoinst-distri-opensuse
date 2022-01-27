<<<<<<< HEAD
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test "# setenforce/getenforce" commands work
#          # setenforce - modify the mode SELinux is running in
#          #   usage:  setenforce [ Enforcing | Permissive | 1 | 0 ]
#          # getenforce - reports whether SELinux is enforcing, permissive, or disabled.
=======
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test '# setenforce/getenforce' commands work
#          # setenforce - modify the mode SELinux is running in
#          #   - usage:  setenforce [ Enforcing | Permissive | 1 | 0 ]
#          # getenforce - reports whether SELinux is enforcing, permissive, or disabled
>>>>>>> 3a0ffc0dbccc64d9a672d2b869bdbc96809ea336
# Maintainer: llzhao <llzhao@suse.com>
# Tags: poo#105202, tc#1769801

use base 'opensusebasetest';
use power_action_utils "power_action";
use strict;
use warnings;
use testapi;
use utils;
<<<<<<< HEAD

sub run {
    my ($self) = @_;

    $self->select_serial_terminal;

    # Set to 'Permissive' mode
    assert_script_run('setenforce Permissive');
    validate_script_output("getenforce", sub { m/Permissive/ });

    # Reboot and check
=======
use Utils::Backends 'is_pvm';

sub run {
    my ($self) = @_;
    my $mode_old = 'Enforcing';
    my $mode_new = 'Permissive';

    $self->select_serial_terminal;

    # Get the current SELinux policy mode
    $mode_old = script_output('getenforce');

    # Set to 'Permissive' mode
    $mode_new = 'Permissive';
    assert_script_run("setenforce $mode_new");
    assert_script_run('setenforce 0');
    validate_script_output('getenforce', sub { m/$mode_new/ });

    # Reboot
>>>>>>> 3a0ffc0dbccc64d9a672d2b869bdbc96809ea336
    power_action("reboot", textmode => 1);
    reconnect_mgmt_console if is_pvm;
    $self->wait_boot(textmode => 1, ready_time => 600, bootloader_time => 300);
    $self->select_serial_terminal;
<<<<<<< HEAD
    validate_script_output("getenforce", sub { m/Permissive/ });

    # Set to 'Enforcing' mode
    assert_script_run('setenforce Enforcing');

    # Reboot and check again
    power_action("reboot", textmode => 1);
    $self->wait_boot(textmode => 1, ready_time => 600, bootloader_time => 300);
    $self->select_serial_terminal;

    validate_script_output("getenforce", sub { m/Enforcing/ });
=======

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
    $self->select_serial_terminal;

    # Check the mode after reboot, the mode returns to original one
    validate_script_output('getenforce', sub { m/$mode_old/ });
>>>>>>> 3a0ffc0dbccc64d9a672d2b869bdbc96809ea336
}

1;
