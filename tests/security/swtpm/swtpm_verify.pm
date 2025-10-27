# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Ship the "swtpm" software TPM emulator for QEMU,
#          test Legacy guest OS under libvirt, cover both
#          TPM 1.2 and TPM 2.0
# Maintainer: QE Security <none@suse.de>
# Tags: poo#81256, tc#1768671, poo#100512

use base 'opensusebasetest';
use swtpmtest;
use testapi;
use serial_terminal 'select_serial_terminal';
use Utils::Architectures;
use version_utils 'is_sle';

sub run {
    select_serial_terminal if !(get_var('MACHINE') =~ /RPi4/);
    # skip test on 15-SP6 when FIPS is enabled due to bsc#1242989
    if (is_sle('=15-SP6') && get_var('FIPS_ENABLED')) {
        record_soft_failure('SKIPPING TEST; poo#179729 bsc#1242989');
        return;
    }
    my $vm_type = check_var('UEFI', '1') ? 'uefi' : 'legacy';
    # aarch64 does not support tpm1.2
    my @swtpm_versions = qw(swtpm_2);
    # Do not test TPM 1.2 on aarch64 or SLE >=15-SP6 if FIPS is enabled
    my $is_legacy_sle = is_sle('<=15-SP5');
    my $is_sle_nonfips = is_sle('>=15-SP6') && !get_var('FIPS_ENABLED');
    my $supports_swtpm1 = !is_aarch64 && ($is_legacy_sle || $is_sle_nonfips);
    push @swtpm_versions, 'swtpm_1' if $supports_swtpm1;
    foreach my $i (@swtpm_versions) {
        start_swtpm_vm($i, "$vm_type");
        swtpm_verify($i);
        stop_swtpm_vm("$vm_type");
    }
}

sub test_flags {
    return {always_rollback => 1};
}

1;
