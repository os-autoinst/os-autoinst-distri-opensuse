# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The test module uses Expert Partitioning wizard on disks with GPT
# partition table to create RAID using data driven pattern. Data is provided
# by yaml scheduling file.
# Maintainer: Oleksandr Orlov <oorlov@suse.de>

use strict;
use warnings;
use parent 'installbasetest';
use testapi;
use version_utils ':VERSION';
use scheduler 'get_test_data';

sub run {
    my $test_data = get_test_data();

    my $partitioner = $testapi::distri->get_expert_partitioner();
    $partitioner->run_expert_partitioner();

    # Create partitions with the data from yaml scheduling file
    # (see YAML_SCHEDULE openQA variable value).
    foreach my $disk (@{$test_data->{disks}}) {
        foreach my $partition (@{$disk->{partitions}}) {
            $partitioner->add_partition_on_gpt_disk({disk => $disk->{name}, partition => $partition});
        }
    }

    # Create RAID partitions with the data from yaml scheduling file
    # (see YAML_SCHEDULE openQA variable value).
    foreach my $md (@{$test_data->{mds}}) {
        $partitioner->add_raid($md);
    }
    $partitioner->accept_changes();
}

1;
