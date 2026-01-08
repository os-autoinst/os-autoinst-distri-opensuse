# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary:  Validate block device information using lsblk.
#
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base "opensusebasetest";
use testapi;

use scheduler 'get_test_suite_data';
use filesystem_utils qw(
  validate_lsblk
  is_lsblk_able_to_display_mountpoints);

sub run {
    select_console('root-console');
    my $disks = get_test_suite_data()->{disks};
    my $size = get_test_suite_data()->{size};

    my $has_mountpoints_col = is_lsblk_able_to_display_mountpoints();

    my $errors;
    foreach my $disk (@{$disks}) {
        $errors .= validate_lsblk(
            device => $disk,
            type => 'disk',
            size => $size,
            has_mountpoints_col => $has_mountpoints_col);
        foreach my $part (@{$disk->{partitions}}) {
            my $part_type = ${part}->{type} // 'part';
            $errors .= validate_lsblk(
                device => $part,
                type => $part_type,
                size => $size,
                has_mountpoints_col => $has_mountpoints_col);
        }
    }
    die "Filesystem validation with lsblk failed:\n$errors" if $errors;
}

1;
