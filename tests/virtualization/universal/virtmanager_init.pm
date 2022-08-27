# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: virt-manager
# Summary: This test connects to hypervisor and check our VMs
# Maintainer: Pavel Dostal <pdostal@suse.cz>, Felix Niederwanger <felix.niederwanger@suse.de>

use base "virt_feature_test_base";
use virt_autotest::common;
use virt_autotest::utils;
use strict;
use warnings;
use testapi;
use utils;
use virtmanager;

sub run_test {
    my ($self) = @_;
    select_console 'root-console';

    zypper_call '-t in virt-manager', exitcode => [0, 4, 102, 103, 106];

    # Ensure additional devices are removed (if present).
    # This is necessary for restarting the virtmanager tests, as we assume the state is clear.
    foreach my $guest (keys %virt_autotest::common::guests) {
        remove_additional_nic($guest, "00:16:3e:32");
        remove_additional_disks($guest);
    }

    #x11_start_program 'virt-manager';
    enter_cmd "virt-manager";

    establish_connection();

    wait_screen_change { send_key 'ctrl-q'; };
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

