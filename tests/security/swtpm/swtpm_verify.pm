# Copyright (C) 2021 SUSE LLC
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
# Summary: Ship the "swtpm" software TPM emulator for QEMU,
#          test Legacy guest OS under libvirt, cover both
#          TPM 1.2 and TPM 2.0
# Maintainer: rfan1 <richard.fan@suse.com>
# Tags: poo#81256, tc#1768671

use base 'opensusebasetest';
use swtpmtest;
use strict;
use warnings;
use testapi;

sub run {
    my $self = shift;
    $self->select_serial_terminal;
    my $vm_type = 'legacy';
    $vm_type = 'uefi' if get_var('HDD_SWTPM_UEFI');
    foreach my $i ("swtpm_1", "swtpm_2") {
        start_swtpm_vm($i, "$vm_type");
        swtpm_verify($i);
        stop_swtpm_vm("$vm_type");
    }
}

sub test_flags {
    return {always_rollback => 1};
}

1;
