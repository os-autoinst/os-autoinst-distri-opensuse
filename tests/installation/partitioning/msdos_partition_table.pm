# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Create new partition table during installation.
# Maintainer: Sofia Syrianidou <ssyrianidou@suse.com>

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
    $partitioner->create_new_partition_table({disk => $test_data->{partition_table_disk}, table_type => $test_data->{table_type}});
    foreach my $disk (@{$test_data->{disks}}) {
        foreach my $partition (@{$disk->{partitions}}) {
            $partitioner->add_partition_msdos({disk => $disk->{name}, partition => $partition});
        }
    }
    $partitioner->accept_changes_and_press_next();
}
1;


