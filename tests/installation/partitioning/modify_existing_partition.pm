# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: modify and resize existing partitions on a pre-formatted disk.
# Maintainer: Jonathan Rivrain <jrivrain@suse.com>

use strict;
use warnings;
use parent 'installbasetest';
use testapi;
use version_utils ':VERSION';
use scheduler 'get_test_suite_data';

sub run {
    my $test_data   = get_test_suite_data();
    my $partitioner = $testapi::distri->get_expert_partitioner();
    $partitioner->run_expert_partitioner();
    $partitioner->resize_partition_on_gpt_disk($test_data);
    $partitioner->edit_partition_on_gpt_disk($test_data);
    $partitioner->accept_changes();
}

1;
