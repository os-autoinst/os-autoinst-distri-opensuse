# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: xen-tools
# Summary: This stops all xl VMs
# Maintainer: QE-Virtualization <qe-virt@suse.de>

use base "consoletest";
use virt_autotest::common;
use strict;
use warnings;
use testapi;
use utils;

sub run {
    foreach my $guest (keys %virt_autotest::common::guests) {
        record_info "$guest", "Stopping xl-$guest guests";
        assert_script_run "xl shutdown -w xl-$guest", 180;
    }

    script_retry "xl list | grep xl", delay => 3, retry => 30, expect => 1;
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

