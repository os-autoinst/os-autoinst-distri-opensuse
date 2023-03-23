# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: vhostmd vm-dump-metrics
# Summary: Prepare the dom0 metrics environment
# Maintainer: QE-Virtualization <qe-virt@suse.de>

use base "consoletest";
use virt_autotest::common;
use virt_autotest::utils;
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    select_console 'root-console';
    select_serial_terminal();

    zypper_call '-t in vhostmd', exitcode => [0, 4, 102, 103, 106];

    foreach my $guest (keys %virt_autotest::common::guests) {
        ensure_online($guest, use_virsh => 0);
        record_info "$guest", "Install vm-dump-metrics on xl-$guest";
        script_retry("ssh root\@$guest 'zypper -n in vm-dump-metrics'", delay => 120, retry => 3);
    }
}

sub test_flags {
    return {fatal => 1, milestone => 0};
}

1;

