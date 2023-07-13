# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Create new partition table during installation.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use parent 'installbasetest';
use testapi;
use scheduler 'get_test_suite_data';

sub run {
    my $test_data = get_test_suite_data;
    my $partitioner = $testapi::distri->get_expert_partitioner;
    $partitioner->run_expert_partitioner;
    foreach my $disk (@{$test_data->{disks}}) {
        $partitioner->create_new_partition_table({name => $disk->{name},
                table_type => $disk->{table_type}, accept_deleting_current_devices_warning => 0});
        foreach my $partition (@{$disk->{partitions}}) {
            $partitioner->add_partition_msdos({
                    disk => $disk->{name},
                    partition => $partition
            });
        }
    }
    $partitioner->accept_changes_and_press_next;
}

1;
