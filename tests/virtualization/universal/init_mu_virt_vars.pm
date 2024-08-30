# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: This file sets the necessary MU virtualization
#   test variables, which can not be given by MU CI tools
#   (bot-ng) during job triggering
# Maintainer: xlai@suse.com, or QE-Virtualization <qe-virt@suse.de>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use main_common;

sub run {
    if (get_var('REGRESSION') =~ /xen|kvm|qemu|hyperv|vmware/) {
        set_mu_virt_vars;
        record_info "Set necessary variables for MU virtualization test is done!";
    }
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
