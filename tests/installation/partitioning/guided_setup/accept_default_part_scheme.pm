# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: The test module just accepts default configuration on
# Partitioning Scheme Screen of Guided Setup.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use parent 'y2_installbase';
use strict;
use warnings;

sub run {
    $testapi::distri->get_partitioning_scheme()->go_forward();
}

1;
