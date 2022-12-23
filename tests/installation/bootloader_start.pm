# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Temporary solution to combine all the bootloader modules in one and
# schedule them depending on the environment variables.
# The solution is implemented to use in declarative scheduling which does not
# allow to use complex conditions.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package bootloader_start;
use strict;
use warnings FATAL => 'all';
use base "installbasetest";
use testapi;
use Utils::Backends;
use utils;
use bootloader;
use bootloader_uefi;
use bootloader_hyperv;
use bootloader_svirt;
use bootloader_zkvm;
use bootloader_s390;
use version_utils qw(:SCENARIO :BACKEND);
use Utils::Architectures;
use File::Basename;
BEGIN {
    unshift @INC, dirname(__FILE__) . '/../boot';
}
use boot_from_pxe;

sub run {
    my $self = shift;
    if (uses_qa_net_hardware() || get_var("PXEBOOT")) {
        record_info('boot_from_pxe');
        $self->boot_from_pxe::run();
        return;
    }
    if (is_s390x()) {
        if (check_var("BACKEND", "s390x")) {
            record_info('bootloader_s390x');
            $self->bootloader_s390::run();
            return;
        }
        else {
            record_info('bootloader_zkvm');
            $self->bootloader_zkvm::run();
            return;
        }
    }
    if (is_svirt && is_x86_64()) {
        set_bridged_networking();
        if (is_hyperv()) {
            record_info('bootloader_hyperv');
            $self->bootloader_hyperv::run();
        }
        else {
            record_info('bootloader_svirt');
            $self->bootloader_svirt::run();
        }
        # In mediacheck we do selection from the bootmenu in installation/mediacheck
        # As normally we also need `bootloader` for this scenario
        return if get_var('MEDIACHECK');
    }
    # Load regular bootloader for all qemu backends and for x84_86 systems,
    # except Xen PV as id does not have VNC (bsc#961638).
    if (is_qemu || (is_svirt && !(check_var('VIRSH_VMM_FAMILY', 'xen') && check_var('VIRSH_VMM_TYPE', 'linux')))) {
        if (get_var('UEFI')) {
            unless (get_var('BOOT_HDD_IMAGE')) {
                record_info('bootloader_uefi');
                $self->bootloader_uefi::run();
                return;
            }
        }
        else {
            record_info('bootloader');
            $self->bootloader::run();
            return;
        }
    }
    # Wrapped call for powerVM
    if (get_var('BACKEND', '') =~ /spvm|pvm_hmc/) {
        record_info('bootloader');
        $self->bootloader::run();
        return;
    }
}

1;
