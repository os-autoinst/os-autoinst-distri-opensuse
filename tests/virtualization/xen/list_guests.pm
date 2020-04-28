#Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: List every guest and check if runs
# Maintainer: Pavel Dostal <pdostal@suse.cz>

use base "consoletest";
use xen;
use strict;
use warnings;
use testapi;
use utils;
use virt_autotest::kernel;

sub run {
    if (script_run("virsh net-list --all | grep default | grep ' active'", 30) != 0) {
        assert_script_run "virsh net-start default";
    }

    assert_script_run "virsh list --all", 90;

    # Check for powered off guests
    if (script_run("virsh list --all | grep \"shut off\"", 90) == 0) {
        foreach my $guest (keys %xen::guests) {
            if (script_run("virsh list --all | grep \"$guest\" | grep \"shut off\"", 90) == 0) {
                record_soft_failure "$guest should be on but is not";
                assert_script_run "virsh start $guest";
            }
        }
    }

    # Check for SSH not ready guests
    foreach my $guest (keys %xen::guests) {
        record_info "$guest", "Establishing connection to $guest";
        script_retry "ping -c3 -W1 $guest", delay => 15, retry => 12;
        assert_script_run "ssh root\@$guest 'hostname -f; uptime'";
    }

    check_virt_kernel();
}

1;

