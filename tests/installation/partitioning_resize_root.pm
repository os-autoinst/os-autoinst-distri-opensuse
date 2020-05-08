# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
#
# Summary: Ensure the root logical volume can be resized on bigger harddisks.
# Maintainer: qa-sle-yast <qa-sle-yast@suse.com>
# Tags: bsc#989976 bsc#1000165

use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use scheduler 'get_test_suite_data';

sub run {
    die "Test needs at least 40 GB HDD size" unless (get_required_var('HDDSIZEGB') > 40);
    my $test_data = get_test_suite_data();

    my $partitioner = $testapi::distri->get_expert_partitioner();
    $partitioner->run_expert_partitioner($test_data->{root}->{expert_partitioner_from});
    $partitioner->resize_partition_on_gpt_disk($test_data->{root});
    $partitioner->accept_changes();
}

1;
