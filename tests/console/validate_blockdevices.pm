# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary:  Validate block device information using lsblk.
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;

use scheduler 'get_test_suite_data';
use filesystem_utils 'validate_lsblk';

sub run {
    select_console('root-console');
    my $disks = get_test_suite_data()->{disks};

    my $errors;
    foreach my $disk (@{$disks}) {
        $errors .= validate_lsblk(device => $disk, type => 'disk');
        foreach my $part (@{$disk->{partitions}}) {
            $errors .= validate_lsblk(device => $part, type => 'part');
        }
    }
    die "Filesystem validation with lsblk failed:\n$errors" if $errors;
}

1;
