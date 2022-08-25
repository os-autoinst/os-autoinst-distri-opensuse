# SUSE's openQA tests
#
# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Setup xen serial console so that ipmitool can work normally from 3rd generation openqa ipmi backend.
# Maintainer: Alice <xlai@suse.com>

use strict;
use warnings;
use testapi;
use base "virt_autotest_base";
use ipmi_backend_utils;

sub run {
    set_grub_on_vh('', '', 'xen') if (get_var("XEN") || check_var("HOST_HYPERVISOR", "xen"));
}

sub test_flags {
    return {fatal => 1};
}

1;
