# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The test module uses Expert Partitioning wizard on disks with GPT
# partition table to create RAID using data driven pattern. Data is provided
# by yaml scheduling file.

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
    $partitioner->run_expert_partitioner();

    # Setup RAID as per test data (see YAML_SCHEDULE and YAML_TEST_DATA openQA variables)
    $partitioner->setup_raid($test_data);
    # Setup lvm as per test data (see YAML_SCHEDULE and YAML_TEST_DATA openQA variables)
    $partitioner->setup_lvm($test_data->{lvm});

    $partitioner->accept_changes_and_press_next();
}

1;
