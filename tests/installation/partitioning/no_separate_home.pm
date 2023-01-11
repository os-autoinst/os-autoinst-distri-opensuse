# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The test module goes through the Suggested Partitioning wizard,
# keeping all the default values but explicitly disables separate /home
# partition.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use parent 'y2_installbase';
use strict;
use warnings FATAL => 'all';
use testapi;

sub run {
    my $partitioner = $testapi::distri->get_partitioner();
    my $multiple_disks = get_var('NUMDISKS', 1) > 1 ? 1 : 0;
    $partitioner->edit_proposal(has_separate_home => 0, multiple_disks => $multiple_disks);
}

1;
