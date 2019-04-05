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

sub run {
    assert_script_run "virsh list --all";
    foreach my $guest (keys %xen::guests) {
        record_info "$guest", "Listing $guest";
        if (script_run("virsh list --all | grep $guest | grep \"shut off\"") == 0) {
            record_soft_failure "Guest $guest should be on but is not";
            assert_script_run "virsh start $guest";
        }
    }
}

1;

