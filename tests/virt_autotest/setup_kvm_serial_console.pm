# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Setup kvm serial console so that ipmitool can work normally from 3rd generation openqa ipmi backend.
# Maintainer: Wayne <wchen@suse.com>

use strict;
use warnings;
use testapi;
use base "virt_autotest_base";
use virt_utils 'is_installed_equal_upgrade_major_release';
use Utils::Backends 'is_remote_backend';
use ipmi_backend_utils;

sub run {
    #online upgrade actually
    if (is_remote_backend && check_var('ARCH', 'aarch64') && is_installed_equal_upgrade_major_release) {
        return;
    }
    else {
        set_serial_console_on_vh('', '', 'kvm') if (check_var("HOST_HYPERVISOR", "kvm") || check_var("SYSTEM_ROLE", "kvm"));
        set_pxe_efiboot('') if check_var('ARCH', 'aarch64');
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
