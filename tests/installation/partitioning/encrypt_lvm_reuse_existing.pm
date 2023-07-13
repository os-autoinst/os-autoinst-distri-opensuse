# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The test module reuses the partition that was created with LVM on
# previous installation and verifies that it is shown in the partitioning list.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use parent 'y2_installbase';
use strict;
use warnings FATAL => 'all';

sub run {
    my $partitioner = $testapi::distri->get_partitioner();
    $partitioner->get_suggested_partitioning_page()->check_existing_encrypted_partition_ignored();
}

1;
