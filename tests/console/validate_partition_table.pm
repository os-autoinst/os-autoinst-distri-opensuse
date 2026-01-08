# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary:  Validate partition table via program 'parted' or 'blkid'.
#
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base "opensusebasetest";
use testapi;

use scheduler 'get_test_suite_data';
use filesystem_utils qw(get_partition_table_via_blkid partition_table);

sub run {
    select_console('root-console');

    my $errors = '';
    foreach my $disk (@{get_test_suite_data()->{disks}}) {
        if (my $expected = $disk->{table_type}) {
            # On s390x zvm, the disk is using dasd, /dev/dasda hasn't uuid,
            # so use parted to check its disks; for other arches, use blkid.
            my $actual = ($disk->{table_type} eq 'dasd') ? partition_table("/dev/$disk->{name}") : get_partition_table_via_blkid("/dev/$disk->{name}");
            if ($expected ne $actual) {
                $errors .= "Wrong partition table in /dev/$disk->{name}. " .
                  "Expected '$expected', got '$actual'\n";
            }
        }
    }
    die "Validation of partition table failed:\n$errors" if $errors;
}

1;
