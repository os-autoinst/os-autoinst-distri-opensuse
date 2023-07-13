# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: xen-tools openssh
# Summary: Obtain the dom0 metrics
# Maintainer: QE-Virtualization <qe-virt@suse.de>

use base "consoletest";
use virt_autotest::common;
use strict;
use warnings;
use testapi;
use utils;

sub run {
    assert_script_run 'vhostmd';

    foreach my $guest (keys %virt_autotest::common::guests) {
        record_info "$guest", "Obtaining dom0 metrics on xl-$guest";
        assert_script_run "xl block-attach xl-$guest /dev/shm/vhostmd0,,xvdc,ro", 180;
        assert_script_run "ssh root\@$guest 'vm-dump-metrics' | grep 'SUSE LLC'";
        assert_script_run "xl block-detach xl-$guest xvdc";
    }
}

sub test_flags {
    return {fatal => 1, milestone => 0};
}

1;

