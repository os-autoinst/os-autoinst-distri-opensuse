# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The test module performs guided partitioning
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use parent 'y2_installbase';
use strict;
use warnings FATAL => 'all';
use testapi;
use scheduler 'get_test_suite_data';

sub run {
    my $test_data = get_test_suite_data()->{guided_partitioning};
    my $guided_setup = $testapi::distri->get_guided_partitioner();
    # Select disks to use, if multiple disks are available
    $guided_setup->setup_disks_to_use(@{$test_data->{disks}}) if $test_data->{disks};
    $guided_setup->setup_partitioning_scheme();
    $guided_setup->setup_filesystem_options($test_data->{filesystem_options});
}

1;
