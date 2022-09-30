# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Ship the "swtpm" software TPM emulator for QEMU,
#          test Legacy guest OS under libvirt, cover both
#          TPM 1.2 and TPM 2.0
# Maintainer: QE Security <none@suse.de>
# Tags: poo#81256, tc#1768671, poo#100512

use base 'opensusebasetest';
use swtpmtest;
use strict;
use warnings;
use testapi;
use Utils::Architectures;

sub run {
    my $self = shift;
    $self->select_serial_terminal if !(get_var('MACHINE') =~ /RPi4/);
    my $vm_type = 'legacy';
    $vm_type = 'uefi' if get_var('HDD_SWTPM_UEFI');
    # aarch64 does not support tpm1.2
    my @swtpm_versions = qw(swtpm_2);
    push @swtpm_versions, qw(swtpm_1) if !is_aarch64;
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
