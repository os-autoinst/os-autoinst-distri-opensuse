# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: The test module just accepts default configuration on
# Select Hard Disk(s) Screen of Guided Setup.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use parent 'y2_installbase';
use strict;
use warnings;

sub run {
    $testapi::distri->get_select_hard_disks()->go_forward();
}

1;
