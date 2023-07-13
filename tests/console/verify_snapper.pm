# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Check if snapper and snapshots subvolume have been set up correctly.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

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
