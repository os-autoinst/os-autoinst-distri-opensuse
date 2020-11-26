# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.
#
# Summary: This scenario uses Expert Partitioner to resize root partition,
# accept warning about root device too small for snapshots and create new
# partition for /usr.
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use parent 'y2_installbase';
use strict;
use warnings;
use scheduler 'get_test_suite_data';

sub run {
    my $test_data = get_test_suite_data();
    my ($root_part, $usr_part) = @{$test_data->{disks}[0]->{partitions}};

    my $partitioner = $testapi::distri->get_expert_partitioner();
    $partitioner->run_expert_partitioner('current');
    $partitioner->resize_partition($root_part);
    $partitioner->add_partition_on_gpt_disk({partition => $usr_part});
    $partitioner->accept_changes_and_press_next();
}

1;
