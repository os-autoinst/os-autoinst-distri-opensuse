# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: TPM2 measured boot test
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#108386

use base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use version_utils 'is_sle';

sub run {
    return unless get_var('QEMUTPM');
    select_serial_terminal;
    if (is_sle('=15-SP2')) {
        record_info('SKIPPING TEST', "Skipping unsupported test on 15-SP2");
        return;
    }

    # Measured boot basic check, in current test logic, it depends on backend qemu and ovmf
    # packages version to check measured boot on VM side. But we have other test modules to
    # cover it on both TW and SLES
    if (get_var('QEMUTPM_VER') eq '2.0') {
        assert_script_run('ls /sys/kernel/security/tpm0/binary_bios_measurements');
        assert_script_run('tpm2_eventlog /sys/kernel/security/tpm0/binary_bios_measurements');
    }
}

1;
