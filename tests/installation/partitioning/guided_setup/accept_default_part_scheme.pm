# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: The test module just accepts default configuration on
# Partitioning Scheme Screen of Guided Setup.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use parent 'y2_installbase';
use strict;
use warnings;

sub run {
    $testapi::distri->get_filesystem_options()->go_forward();
}

1;
