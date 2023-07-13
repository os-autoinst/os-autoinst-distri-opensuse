# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate partitioning free space in the corresponding unit
#          using program 'parted'.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;

use scheduler 'get_test_suite_data';
use filesystem_utils 'free_space';

sub run {
    select_console('root-console');
    my $errors = '';
    my $disks = get_test_suite_data()->{disks};

    my ($expected, $unit, $actual);
    foreach my $disk (@{$disks}) {
        if ($expected = $disk->{allowed_unpartitioned}) {
            $expected =~ /(?<size>\d+\.\d+)(?<unit>.*)/;
            $expected = $+{size};
            $unit = $+{unit};
            $actual = {free_space(
                    dev => "/dev/$disk->{name}",
                    unit => $unit)}->{size};
            if ($expected ne $actual) {
                $errors .= "Wrong free space in /dev/$disk->{name}. " .
                  "Expected '$expected$unit', got '$actual$unit'\n";
            }
        }
    }
    die "Validation of free space using program 'parted' failed:\n$errors" if $errors;
}

1;
