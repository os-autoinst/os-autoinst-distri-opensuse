# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The test module reuses the partition that was created with LVM on
# previous installation and verifies that it is shown in the partitioning list.
# Maintainer: Oleksandr Orlov <oorlov@suse.de>

use strict;
use warnings FATAL => 'all';
use parent "installbasetest";

sub run {
    my $partitioner = $testapi::distri->get_partitioner();
    $partitioner->get_suggested_partitioning_page()->check_existing_encrypted_partition_ignored();
}

1;
