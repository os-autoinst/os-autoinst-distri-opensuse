# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Validate partitioning for autoyast installation when using whole disk as PV
#          We have 2 disks, one contains bios boot and /boot partitions, second one
#          is used for LVM group with root and swap logical volumes.
# Maintainer: Rodion Iafarov <riafarov@suse.com>

use strict;
use base 'basetest';
use testapi;

sub validate_disk_as_partition {
    my $errors = '';
    record_info('Verify root partition as disk');
    # Validate type of the partition
    my $output = script_output('lsblk /dev/sda --noheading --output TYPE');
    if ($output !~ 'disk') {
        $errors .= "Expected type disk for /dev/vda, got: $output\n";
    }
    # Validate mount point of the partition
    $output = script_output('lsblk /dev/sda --noheading --output MOUNTPOINT');
    if ($output !~ '/') {
        $errors .= "Expected '/' mount point disk for /dev/vda, got: $output\n";
    }
    return $errors;
}

sub validate_vg_partitions {
    my $errors = '';
    record_info('Verify volume group on disk as PV');
    # Validate volume group exists
    assert_script_run('vgdisplay system');
    # Validate logical volume
    my $lmv_disk_scan = script_output('lvmdiskscan');
    if ($lmv_disk_scan !~ '1 LVM physical volume whole disk') {
        $errors .= "Disk is not detected as physical volume, but expected to be LVM PV\n";
    }
    for my $partition (qw(swap home)) {
        if ($lmv_disk_scan !~ "/dev/system/$partition") {
            $errors .= "$partition partition is not created as expected, expected /dev/system/$partition LV\n";
        }
    }
    return $errors;
}

sub validate_mount_points {
    my $errors = '';
    record_info('Verify mount points');
    for my $mount (qw(/ /home)) {
        if (script_run("findmnt $mount") != 0) {
            $errors .= "No mount point found for $mount\n";
        }
    }
    return $errors;
}

sub validate_swap {
    record_info('Verify swap partition');
    my $swap_size = script_output('swapon --show=SIZE --noheadings');
    if ($swap_size !~ '2G') {
        return "Expected 2G size for the swap partition, got: $swap_size\n";
    }
    return '';
}

sub run {
    my $errors = '';
    select_console('root-console');
    $errors .= validate_disk_as_partition;
    $errors .= validate_vg_partitions;
    $errors .= validate_mount_points;
    $errors .= validate_swap;

    die("Test failed:\n$errors") if $errors;

}

1;
