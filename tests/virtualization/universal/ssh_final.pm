# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: openssh hostname iputils
# Summary: This checks all VMs over SSH
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base "virt_feature_test_base";
use strict;
use warnings;
use virt_autotest::common;
use strict;
use testapi;
use utils;

sub run_test {
    my @guests = keys %virt_autotest::common::guests;
    foreach my $guest (@guests) {
        record_info "$guest", "Establishing SSH connection to $guest";
        assert_script_run "ping -c3 -W1 $guest";
        assert_script_run "ssh root\@$guest 'hostname -f; uptime'";
    }
}

1;

