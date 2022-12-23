# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary:  Validate partition table via program 'parted'.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;

use scheduler 'get_test_suite_data';
use filesystem_utils 'partition_table';

sub run {
    select_console('root-console');
    my $errors = '';
    my $disks = get_test_suite_data()->{disks};

    my $actual;
    foreach my $disk (@{$disks}) {
        if (my $expected = $disk->{table_type}) {
            $actual = partition_table("/dev/$disk->{name}");
            if ($expected ne $actual) {
                $errors .= "Wrong partition table in /dev/$disk->{name}. " .
                  "Expected '$expected', got '$actual'\n";
            }
        }
    }
    die "Validation of partition table using program 'parted' failed:\n$errors" if $errors;
}

1;
