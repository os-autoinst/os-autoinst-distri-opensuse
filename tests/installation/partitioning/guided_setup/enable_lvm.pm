# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: The test module enables LVM on Partitioning Scheme Screen of Guided Setup
# and navigates to the next screen.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use parent 'y2_installbase';
use strict;
use warnings;

sub run {
    my $partitioning_scheme = $testapi::distri->get_partitioning_scheme();
    $partitioning_scheme->enable_lvm();
    $partitioning_scheme->go_forward();
}

1;
