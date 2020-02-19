# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Validation of filesystem table type, filesystem partitioning, reading and writting in specified partitions, check of unpartitioned disk space.
# Maintainer: Sofia Syrianidou <ssyrianidou@suse.com>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use scheduler 'get_test_suite_data';
use Test::Assert ':all';
use partitions_validator_utils qw(
  validate_partition_table
  validate_partition_creation
  validate_filesystem
  validate_read_write
  validate_unpartitioned_space);

sub run {

    select_console "root-console";
    my $test_data = get_test_suite_data();
    if (defined $test_data->{table_type}) {
        # Validate that the partition table type is the expected one.
        validate_partition_table({device => "/dev/" . $test_data->{partition_table_disk}, table_type => $test_data->{table_type}});
    }

    foreach my $disk (@{$test_data->{disks}}) {
        foreach my $partition (@{$disk->{partitions}}) {
            # Validate that all partitions were created.
            my $mnt = $partition->{mounting_options}->{mount_point};
            # Avoiding checking prep-boot partition creation, which does not have a defined mount point.
            validate_partition_creation({mount_point => $mnt}) if $mnt;
            # "validation_flag" is used in order to avoid validating filesystem type and ability to read-write in swap and boot partitions.
            if ($partition->{validation_flag} == 1) {
                # Validate the partitions' filesystem is the expected one.
                my $fmt = $partition->{formatting_options}->{filesystem};
                validate_filesystem({mount_point => $mnt, fs_type => $fmt});
                validate_read_write({mount_point => $mnt});
            }
        }

        if (defined $disk->{allowed_unpartitioned}) {
            validate_unpartitioned_space({disk => $disk->{name}, allowed_unpartitioned => $disk->{allowed_unpartitioned}});
        }
    }
}

1;


