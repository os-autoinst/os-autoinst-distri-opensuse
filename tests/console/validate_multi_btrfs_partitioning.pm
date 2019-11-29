# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Data-driven validation module to check multi-device Btrfs setup.
# Test data must be specified in the corresponding yaml file.
# Scenarios covered:
# - Verify labels for all the mount points provided from test data (e.g. "/", "/test");
# - Verify the number of devices used for multi-device Btrfs filesystems;
# - Verify devices that are used in multi-device Btrfs filesystems.
# Maintainer: Oleksandr Orlov <oorlov@suse.de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use scheduler 'get_test_suite_data';
use Test::Assert ':all';

sub run {

    my $test_data     = get_test_suite_data();
    my @multi_devices = @{$test_data->{multi_devices}};

    select_console 'root-console';

    foreach (@multi_devices) {
        my $mount_point              = $_->{mount_point};
        my $btrfs_multidevice_output = script_output("btrfs filesystem show $mount_point");

        record_info("Label", "Verify label for \"$mount_point\" mount point");
        assert_true($btrfs_multidevice_output =~ $_->{label},
            "Wrong label is shown for multi-device Btrfs with \"$mount_point\" mount point");

        record_info("Number of devices", "Verify the number of devices used for multi-device Btrfs with \"$mount_point\" mount point corresponds to the expected");
        my @partitions_count = ($btrfs_multidevice_output =~ /devid/g);
        assert_equals(scalar @{$_->{devices}}, @partitions_count,
            "Multi-device Btrfs with \"$mount_point\" mount point contains wrong number of devices");

        foreach (@{$_->{devices}}) {
            record_info("$_", "Verify the device \"$_\" is used in multi-device Btrfs with \"$mount_point\" mount point");
            assert_true($btrfs_multidevice_output =~ $_,
                "Multi-device Btrfs with \"$mount_point\" mount point does not contain the expected device \"$_\"");
        }
    }
}

1;
