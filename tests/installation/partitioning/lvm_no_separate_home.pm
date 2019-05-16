# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The test module creates a partition with LVM and explicitly disables
# separate /home partition.
# Maintainer: Oleksandr Orlov <oorlov@suse.de>

use parent 'y2_installbase';
use strict;
use warnings FATAL => 'all';

sub run {
    my $partitioner = $testapi::distri->get_partitioner();
    $partitioner->edit_proposal(is_lvm => 1, has_separate_home => 0);
}

1;
