# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary:  Validate partition table via program 'blkid'.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;

use scheduler 'get_test_suite_data';
use filesystem_utils qw(get_partition_table_via_blkid partition_table);

sub run {
    select_console('root-console');
    my $errors = '';
    my $disks = get_test_suite_data()->{disks};

    my $actual;
    my $table_type_parted = get_test_suite_data()->{table_type_parted};
    my $progm = ($table_type_parted eq '1') ? 'parted' : 'blkid';
    foreach my $disk (@{$disks}) {
        if (my $expected = $disk->{table_type}) {
            $actual = ($table_type_parted eq '1') ? partition_table("/dev/$disk->{name}") : get_partition_table_via_blkid("/dev/$disk->{name}");
            if ($expected ne $actual) {
                $errors .= "Wrong partition table in /dev/$disk->{name}. " .
                  "Expected '$expected', got '$actual'\n";
            }
        }
    }
    die "Validation of partition table using program '$progm' failed:\n$errors" if $errors;
}

1;
