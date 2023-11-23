# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Install custom kernel and remove kernel-default (if it is requested)
# Maintainer: QE Kernel <kernel-qa@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(zypper_call);
use kernel 'get_kernel_flavor';

sub run {
    select_serial_terminal;

    my $kernel_flavor = get_kernel_flavor;
    if (get_kernel_flavor ne 'kernel-default') {
        zypper_call("in +${kernel_flavor} -kernel-default -kernel-default-devel -kernel-macros -kernel-source", exitcode => [0, 104]);
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
