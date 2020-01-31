# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Validate ext4 filesystem and system partitioning.
# Maintainer: Sofia Syrianidou <ssyrianidou@suse.com>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use scheduler 'get_test_suite_data';
use Test::Assert ':all';
use partitions_validator_utils 'validate_partition_table';

sub run {

    select_console "root-console";
    my $test_data  = get_test_suite_data();
    my @partitions = @{$test_data->{partitions}};

    validate_partition_table({device => $test_data->{device}, table_type => $test_data->{table_type}});

    foreach (@partitions) {
        if ($_->{mnt_point} eq '[SWAP]') {
            record_info("Check $_->{mnt_point}", "Verify the '$_->{mnt_point}' partition was created and the filesystem is '$_->{fs_type}'");
            # Validate that the partition is created.
            assert_script_run("lsblk -n | grep SWAP", fail_message => "Partition SWAP was not created.");
            # Validate that the filesystem type is the expected one.
            my $fstype = script_output("cat /etc/fstab | grep swap | awk '{print \$3}'");
            assert_equals($_->{fs_type}, $fstype, "File system on '$_->{mnt_point}' partition does not correspond to the expected one.");
        }
        else {
            record_info("Check $_->{mnt_point}", "Verify the '$_->{mnt_point}' partition was created and the filesystem is '$_->{fs_type}'");
            # Validate that the partition is created.
            assert_script_run("lsblk -n | grep $_->{mnt_point}\$", fail_message => "Partition $_->{mnt_point} was not created.");
            # Validate that the filesystem type is the expected one.
            my $fstype = script_output("df -PT $_->{mnt_point} | grep -v \"Filesystem\" | awk '{print \$2}'");
            assert_equals($_->{fs_type}, $fstype, "File system on '$_->{mnt_point}' partition does not correspond to the expected one.");
            # Test the ability to read and write files on the partition.
            assert_script_run("echo Hello > $_->{mnt_point}/emptyfile", fail_message => 'Failure while writing in ' . $_->{mnt_point});
            assert_script_run("cat $_->{mnt_point}/emptyfile",          fail_message => 'Failure while reading from ' . $_->{mnt_point});
        }
    }

    # Validate that there is no unpartitioned space.
    my $device = $test_data->{device};
    record_info("Check $device partitioning", "Verify the '$device' does not have unpartitioned disk space");
    my $unpartitioned = script_output("parted $device unit GB print free | grep 'Free Space' | tail -n1 | awk '{print \$3}'");
    die "There is $unpartitioned unpartitioned disk space." if ($unpartitioned ne $test_data->{allowed_unpartitioned});

}

1;


