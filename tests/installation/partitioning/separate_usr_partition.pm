# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: This scenario uses Expert Partitioner to resize root partition,
# accept warning about root device too small for snapshots and create new
# partition for /usr.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use parent 'y2_installbase';
use strict;
use warnings;
use scheduler 'get_test_suite_data';

sub run {
    my $test_data = get_test_suite_data();
    my $disk = $test_data->{disks}[0]->{name};
    my ($root_part, $usr_part) = @{$test_data->{disks}[0]->{partitions}};

    my $partitioner = $testapi::distri->get_expert_partitioner();
    $partitioner->run_expert_partitioner('current');
    $partitioner->resize_partition({disk => $disk, partition => $root_part});
    $partitioner->add_partition_on_gpt_disk({disk => $disk, partition => $usr_part});
    $partitioner->accept_changes_and_press_next();
}

1;
