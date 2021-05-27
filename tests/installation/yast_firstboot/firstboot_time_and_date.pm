# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Handles Time and Date dialog in YaST Firstboot Configuration.
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use base 'y2_firstboot_basetest';
use strict;
use warnings;
use scheduler 'get_test_suite_data';
use cfg_files_utils;

sub run {
    my $test_data           = get_test_suite_data()->{time_and_date};
    my $clock_and_time_zone = $testapi::distri->get_clock_and_time_zone();
    compare_settings({
            expected      => $test_data,
            current       => $clock_and_time_zone->collect_current_clock_and_time_zone_info(),
            suppress_info => 1});
    $clock_and_time_zone->proceed_with_current_configuration();
}

1;
