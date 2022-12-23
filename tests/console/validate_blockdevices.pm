# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary:  Validate block device information using lsblk.
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;

use scheduler 'get_test_suite_data';
use filesystem_utils qw(
  validate_lsblk
  is_lsblk_able_to_display_mountpoints);

sub run {
    select_console('root-console');
    my $disks = get_test_suite_data()->{disks};

    my $has_mountpoints_col = is_lsblk_able_to_display_mountpoints();

    my $errors;
    foreach my $disk (@{$disks}) {
        $errors .= validate_lsblk(
            device => $disk,
            type => 'disk',
            has_mountpoints_col => $has_mountpoints_col);
        foreach my $part (@{$disk->{partitions}}) {
            $errors .= validate_lsblk(
                device => $part,
                type => 'part',
                has_mountpoints_col => $has_mountpoints_col);
        }
    }
    die "Filesystem validation with lsblk failed:\n$errors" if $errors;
}

1;
