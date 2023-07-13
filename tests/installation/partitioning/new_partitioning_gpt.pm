# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: The test module uses Expert Partitioning wizard on disks with GPT
# partition table to perform installation using data driven pattern. Data is
# provided by yaml scheduling file.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use parent 'y2_installbase';

use strict;
use warnings;

use testapi;
use version_utils ':VERSION';
use scheduler 'get_test_suite_data';

sub run {
    my $test_data = get_test_suite_data();

    my $partitioner = $testapi::distri->get_expert_partitioner();
    $partitioner->run_expert_partitioner('current');

    my $disk = $test_data->{disks}[0];
    $partitioner->create_new_partition_table({name => $disk->{name}, accept_deleting_current_devices_warning => 1});

    foreach my $partition (@{$disk->{partitions}}) {
        $partitioner->add_partition_on_gpt_disk({
                disk => $disk->{name},
                partition => $partition
        });
    }

    $partitioner->setup_lvm($test_data->{lvm}) if ($test_data->{lvm});
    $partitioner->accept_changes_and_press_next();
}

1;
