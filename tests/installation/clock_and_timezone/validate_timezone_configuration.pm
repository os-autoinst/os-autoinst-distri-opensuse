# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Collects all the info about current Timezone configuration
# and validates it against the one provided by test_data.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';
use strict;
use warnings;
use scheduler 'get_test_suite_data';
use cfg_files_utils;

sub run {
    my $test_data = get_test_suite_data()->{time_and_date};

    my $clock_and_time_zone = $testapi::distri->get_clock_and_time_zone();
    compare_settings({
            expected => $test_data,
            current => $clock_and_time_zone->collect_current_clock_and_time_zone_info(),
            suppress_info => 1});
}

1;
