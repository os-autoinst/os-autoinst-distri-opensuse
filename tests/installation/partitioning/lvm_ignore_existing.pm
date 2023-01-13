# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The test module ignores a partition that was created on previous
# installation and configures the partition with LVM. Then verifies that the
# partition is shown in the partitioning list.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use parent 'y2_installbase';
use strict;
use warnings FATAL => 'all';

sub run {
    my $partitioner = $testapi::distri->get_partitioner();
    $partitioner->edit_proposal_for_existing_partition(is_lvm => 1, is_encrypted => 0);
    $partitioner->get_suggested_partitioning_page()->assert_partition_with_lvm_shown_in_the_list();
}

1;
