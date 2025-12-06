# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: usb_nic
# Summary: Simple smoke test for testing USB drive connected to system
# Maintainer: LSG QE Kernel <kernel-qa@suse.de>

use base 'opensusebasetest';
use testapi;
use serial_terminal;
use utils;
use package_utils 'install_package';
use version_utils 'is_sle';
use Kernel::usb;

sub md5sum {
    my ($file) = @_;
    my ($md5) = split /\s/, script_output "md5sum $file";
    return $md5;
}


sub run {
    my ($self) = @_;

    select_serial_terminal;
    check_usb_devices;

    my $lun = script_output 'lsscsi -t -v | awk -F" " \'/usb/ {split($2,a,/[\/]/); print a[6]}\'';
    die "no usb storage device connected" if $lun eq "";

    my $device = "/dev/" . script_output "lsscsi -v | awk -F\"/\" \'/$lun/ {print \$3; exit}\'";

    # create filesystem, mountpoint and temporary file
    my $tmp = script_output 'mktemp -d';
    my $file = "$tmp/file";
    my $mountpoint = "$tmp/mount";
    my $file_copy = "$mountpoint/file";

    assert_script_run "mkdir $mountpoint";
    assert_script_run "chgrp disk $mountpoint";
    assert_script_run "chmod 777 $mountpoint";

    assert_script_run "mkfs.ext4 -F $device";
    assert_script_run "mount -t ext4 $device $mountpoint";

    assert_script_run "dd if=/dev/urandom of=$file bs=1M count=16";
    my $md5_orig = md5sum $file;
    assert_script_run "cp $file $file_copy";

    # unmount and flush slab and page cache
    assert_script_run "umount $mountpoint";
    assert_script_run "echo 3 > /proc/sys/vm/drop_caches";

    # remount and check md5sum
    assert_script_run "mount -t ext4 $device $mountpoint";
    my $md5_copy = md5sum $file_copy;
    die "MD5 sum mismatch: $md5_orig != $md5_copy" unless $md5_orig eq $md5_copy;
    assert_script_run("umount $mountpoint");


    if (@{zypper_search('lklfuse')}) {
        install_package 'lklfuse';
        assert_script_run "usermod -a -G disk bernhard";

        select_user_serial_terminal;
        $mountpoint = "/home/bernhard/mount";
        $file = "/home/bernhard/file";
        $file_copy = "$mountpoint/file2";

        assert_script_run "dd if=/dev/urandom of=$file bs=1M count=15";
        $md5_orig = md5sum $file;
        assert_script_run "mkdir -p $mountpoint";
        assert_script_run "lklfuse $device $mountpoint -o type=ext4";
        my $mounts = script_output "mount";
        die "$mountpoint not found in mtab!" unless $mounts =~ /\Q$mountpoint\E/;
        assert_script_run "cp $file $file_copy";
        assert_script_run "fusermount -u $mountpoint";
        assert_script_run "sync";
        # make sure the file doesn't exist after unmointing, this would mean the device wasn't mounted
        assert_script_run "! [ -f $file_copy ]";
        assert_script_run "lklfuse $device $mountpoint -o type=ext4";
        record_info "Drive contents", script_output("ls $mountpoint");
        my $md5_copy = md5sum $file_copy;
        die "MD5 sum mismatch: $md5_orig != $md5_copy" unless $md5_orig eq $md5_copy;
        assert_script_run "sync";
        script_run "fusermount -u $mountpoint";

    } elsif (is_sle('16+')) {
        die "running on SLE16+ but lklfuse package is missing";
    }
}

sub test_flags {
    return {fatal => 0};
}

1;
