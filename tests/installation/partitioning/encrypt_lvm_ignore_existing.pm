# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The test module ignores a partition that was created on previous
# installation and configures the partition with LVM. Then verifies that the
# partition is shown in the partitioning list.
# Maintainer: Oleksandr Orlov <oorlov@suse.de>

use strict;
use warnings FATAL => 'all';
use parent "y2logsstep";

sub run {
    my $partitioner = $testapi::distri->get_partitioner();
    $partitioner->get_suggested_partitioning_page()->check_existing_encrypted_partition_ignored();
    $partitioner->edit_proposal_for_existing_partition(is_lvm => 1, is_encrypted => 1);
    $partitioner->get_suggested_partitioning_page()->assert_encrypted_partition_with_lvm_shown_in_the_list();
}

1;
