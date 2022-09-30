# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: With kernel 5.6+, apply ima_measure_critical_data patches,
#          and enable CONFIG_IMA_QUEUE_EARLY_BOOT_KEYS kernel config.
#          We need check this feature on SLES15SP4 on aarch64 platform
#          only, IBM will cover other platforms.
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#102707, tc#1769822

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;
use power_action_utils 'power_action';
use bootloader_setup 'add_grub_cmdline_settings';

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    # Make sure CONFIG_IMA_QUEUE_EARLY_BOOT_KEYS is enabled in our kernel
    my $results = script_run('zcat /proc/config.gz | grep CONFIG_IMA_QUEUE_EARLY_BOOT_KEYS=y');
    if ($results) {
        die('Error: the kernel parameter CONFIG_IMA_QUEUE_EARLY_BOOT_KEYS is not set correctly');
    }

    # Add the kernel parameter to verify it can work
    add_grub_cmdline_settings('ima_policy=critical_data', update_grub => 1);

    # Reboot to make settings work
    power_action('reboot', textmode => 1);
    $self->wait_boot;
    $self->select_serial_terminal;

    # Default template ima-buf should be used
    my $meas_file = '/sys/kernel/security/ima/ascii_runtime_measurements';
    assert_script_run(
        "cat $meas_file |grep '^10\\s*[a-fA-F0-9]\\{40\\}\\s*ima-buf\\s*sha256:[a-fA-F0-9]\\{64\\}\\s*kernel_version'",
        timeout => '60',
        fail_message => 'template check failed'
    );
}

1;
