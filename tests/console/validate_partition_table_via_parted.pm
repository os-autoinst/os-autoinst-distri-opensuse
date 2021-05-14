# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary:  Validate partition table via program 'parted'.
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;

use scheduler 'get_test_suite_data';
use filesystem_utils 'partition_table';

sub run {
    select_console('root-console');
    my $errors = '';
    my $disks  = get_test_suite_data()->{disks};

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
