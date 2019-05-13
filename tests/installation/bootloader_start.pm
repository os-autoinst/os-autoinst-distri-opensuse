# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Temporary solution to combine all the bootloader modules in one and
# schedule them depending on the environment variables.
# The solution is implemented to use in declarative scheduling which does not
# allow to use complex conditions.
# Maintainer: Oleksandr Orlov <oorlov@suse.de>

package bootloader_start;
use strict;
use warnings FATAL => 'all';
use base "installbasetest";
use testapi;
use utils;
use bootloader;
use bootloader_uefi;
use bootloader_hyperv;
use bootloader_svirt;
use version_utils qw(:SCENARIO :BACKEND);
use Utils::Architectures;
use File::Basename;
BEGIN {
    unshift @INC, dirname(__FILE__) . '/../boot';
}
use boot_from_pxe;

sub run {
    if (uses_qa_net_hardware() || get_var("PXEBOOT")) {
        boot_from_pxe::run;
        return;
    }
    if (is_s390x()) {
        if (check_var("BACKEND", "s390x")) {
            bootloader_s390::run();
            return;
        }
        else {
            bootloader_zkvm::run();
            return;
        }
    }
    if (check_var('BACKEND', 'svirt') && is_x86_64()) {
        set_bridged_networking();
        if (is_hyperv()) {
            bootloader_hyperv::run();
        }
        else {
            bootloader_svirt::run();
        }
    }
    # Load regular bootloader for all qemu backends and for x84_86 systems,
    # except Xen PV as id does not have VNC (bsc#961638).
    if (check_var('BACKEND', 'qemu') || (check_var('BACKEND', 'svirt') && !(check_var('VIRSH_VMM_FAMILY', 'xen') && check_var('VIRSH_VMM_TYPE', 'linux')))) {
        if (get_var('UEFI')) {
            bootloader_uefi::run();
            return;
        }
        else {
            bootloader::run();
            return;
        }
    }
    else {
        die 'No bootloader found for the current job settings.';
    }
}

1;
