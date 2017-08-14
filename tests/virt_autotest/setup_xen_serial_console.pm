# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Setup xen serial console so that ipmitool can work normally from 3rd generation openqa ipmi backend.
# Maintainer: Alice <xlai@suse.com>

use strict;
use warnings;
use testapi;
use base "virt_autotest_base";
use ipmi_backend_utils;

sub run {
    set_serial_console_on_xen if (get_var("XEN") || check_var("HOST_HYPERVISOR", "xen"));
}

sub test_flags {
    return {fatal => 1};
}

1;
