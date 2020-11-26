# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The test module uses Expert Partitioning wizard on disks with GPT
# partition table to create RAID using data driven pattern. Data is provided
# by yaml scheduling file.

# Maintainer: QE YaST <qa-sle-yast@suse.de>

use parent 'y2_installbase';

use strict;
use warnings;

use testapi;
use version_utils ':VERSION';
use scheduler 'get_test_suite_data';

sub run {
    my $test_data = get_test_suite_data();

    my $partitioner = $testapi::distri->get_expert_partitioner();
    $partitioner->run_expert_partitioner();

    # Setup RAID as per test data (see YAML_SCHEDULE and YAML_TEST_DATA openQA variables)
    $partitioner->setup_raid($test_data);

    # Add volume groups and logical volumes as per test data
    foreach my $vg (@{$test_data->{lvm}->{volume_groups}}) {
        $partitioner->add_volume_group($vg);
        foreach my $lv (@{$vg->{logical_volumes}}) {
            $partitioner->add_logical_volume({
                    volume_group   => $vg->{name},
                    logical_volume => $lv
            });
        }
    }

    $partitioner->accept_changes_and_press_next();
}

1;
