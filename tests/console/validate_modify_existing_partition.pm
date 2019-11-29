# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Verify the partition modified in modify_existing_partition.
# Maintainer: Jonathan Rivrain <jrivrain@suse.com>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use scheduler 'get_test_suite_data';
use Test::Assert ':all';

sub run {
    my $test_data = get_test_suite_data();

    select_console "root-console";

    record_info("Check $test_data->{fs_type}", "Verify that the partition filesystem is $test_data->{fs_type}");
    my $fstype = script_output("df -PT $test_data->{mount_point} | grep -v \"Filesystem\" | awk '{print \$2}'");
    assert_equals($test_data->{fs_type}, $fstype);

    record_info("Check size", "Verify that the partition size is $test_data->{part_size}");
    my $partsize = script_output("lsblk | grep $test_data->{existing_partition} | awk '{print \$4}'");
    assert_equals($test_data->{lsblk_expected_size_output}, $partsize);
}

1;
