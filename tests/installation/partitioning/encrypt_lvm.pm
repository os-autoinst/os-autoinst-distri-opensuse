# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The test module creates an encrypted partition with LVM and verifies
# that it is shown in the partitioning list.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use parent 'y2_installbase';
use strict;
use warnings FATAL => 'all';
use testapi;

sub has_multiple_disks {
    return 1 if (get_var('NUMDISKS', 0) > 1 || get_var('IBFT'));
    return 0;
}

sub run {
    my $partitioner = $testapi::distri->get_partitioner();
    $partitioner->edit_proposal(multiple_disks => has_multiple_disks, is_lvm => 1, is_encrypted => 1);
    $partitioner->get_suggested_partitioning_page()->assert_encrypted_partition_with_lvm_shown_in_the_list();
}

1;
