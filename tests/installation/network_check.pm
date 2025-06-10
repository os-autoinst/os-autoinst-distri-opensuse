# SUSE's openQA tests
#
# Copyright 2025
# SPDX-License-Identifier: FSFAP

# Summary: Make sure NIC is up and ip address
#          is allocated after installation
#
# - We only need to care about QEMU backend
# Maintainer: QE Core <qe-core@suse.de>

use strict;
use warnings;
use base 'consoletest';
use testapi;
use Utils::Backends 'is_qemu';

sub qemu_backend_ifup_check {
    return unless is_qemu;
    if (get_var('IFUP_CHECK', '1')) {
        my $vm_ip_addr = get_var('VM_IP_ADDR', '10.0.2.15');
        my $vm_ip_route = get_var('VM_IP_ROUTE', '10.0.2.2');
        die 'No ip addresse is allocated' unless (script_run("ip a | grep $vm_ip_addr") == 0);
        die 'The gateway is not accessible' unless (script_run("ping -c 3 $vm_ip_route") == 0);
    }
}

sub run {
    select_console 'root-console';
    qemu_backend_ifup_check();
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
