# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.
#
# Summary: Verify that quota is set and corresponds to the expected limit for the required subvolumes.
# The list of subvolumes and expected quota limit are stored in 'test_data'.
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use base 'basetest';
use strict;
use warnings;
use testapi;
use scheduler 'get_test_suite_data';
use Test::Assert 'assert_equals';

sub run {
    my $test_data = get_test_suite_data();
    foreach my $disk (@{$test_data->{disks}}) {
        foreach my $partition (@{$disk->{partitions}}) {
            my $mount_point             = $partition->{mounting_options}->{mount_point};
            my $output_btrfs_subvolumes = assert_script_run("btrfs subvolume list $mount_point");
            # Get 'qgroupid' and 'max_rfer' columns from the output. Other columns are not needed for this test.
            my $output_btrfs_qgroups = assert_script_run("btrfs qgroup show -r $mount_point | awk '{print \$1,\$4}'");
            foreach my $subvolume (@{$partition->{subvolumes}}) {
                # Parse id for the subvolume path
                (my $subvolume_id) = ($output_btrfs_subvolumes =~ /ID\s*([0-9]*).*?$subvolume->{path}/);
                # Parse quota size using subvolume id
                (my $quota_size) = ($output_btrfs_qgroups =~ /0\/$subvolume_id\s*(\d+.\d+\w+)/);
                assert_equals($subvolume->{quota_size}, $quota_size,
                    "Quota size for $subvolume->{path} does not match the expected.");
            }
        }
    }
}

1;
