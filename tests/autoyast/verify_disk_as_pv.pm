# SUSE's openQA tests
#
# Copyright 2018-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: util-linux lvm2
# Summary: Validate partitioning for autoyast installation when using whole disk as PV
#          We have 2 disks, one contains bios boot and /boot partitions, second one
#          is used for LVM group with root and swap logical volumes.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base 'basetest';
use testapi;

sub validate_disk_as_partition {
    my $errors = '';
    record_info('Verify root partition as disk');
    # Validate type of the partition
    my $output = script_output('lsblk /dev/sdb --noheading --output TYPE');
    if ($output !~ 'disk') {
        $errors .= "Expected type disk for /dev/sdb, got: $output\n";
    }
    # Validate mount point of the partition
    $output = script_output('lsblk /dev/sdb --noheading --output MOUNTPOINT');
    if ($output !~ '/') {
        $errors .= "Expected '/' mount point disk for /dev/sdb, got: $output\n";
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
    my $lvm_lvscan = script_output('lvm lvscan');
    for my $partition (qw(swap home)) {
        if ($lvm_lvscan !~ "/dev/system/$partition") {
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
