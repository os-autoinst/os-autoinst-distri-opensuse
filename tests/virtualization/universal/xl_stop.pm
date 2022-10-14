# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: xen-tools
# Summary: This stops all xl VMs
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my @guests = @{get_var_array("TEST_GUESTS")};
    foreach my $guest (@guests) {
        record_info "$guest", "Stopping xl-$guest guests";
        assert_script_run "xl shutdown -w xl-$guest", 180;
    }

    script_retry("xl list xl-$_", delay => 3, retry => 30, expect => 1) foreach (@guests);
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

