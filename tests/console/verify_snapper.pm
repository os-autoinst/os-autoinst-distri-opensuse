# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.
#
# Summary: Check if snapper and snapshots subvolume have been set up correctly.
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use strict;
use warnings;
use parent 'y2_module_consoletest';
use testapi;

sub run {
    assert_script_run("snapper list", fail_message => "Snapper has not been set up correctly");

    assert_script_run("btrfs subvolume list / | grep '@/.snapshots'", timeout => 180,
        failure_message => "Snapshots subvolume is not found in snapper list");

    assert_script_run("grep '/\.snapshots .*subvol=/@/\.snapshots' /etc/fstab", timeout => 180,
        failure_message => "Snapshots subvolume is not set in fstab file");

}

1;
