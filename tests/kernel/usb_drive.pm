# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: usb_nic
# Summary: Simple smoke test for testing USB drive connected to system
# Maintainer: LSG QE Kernel <kernel-qa@suse.de>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use package_utils 'install_package';
use version_utils 'is_sle';
use usb;

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
    my $md5 = "$tmp/md5";
    my $mountpoint = "$tmp/mount";
    my $file_copy = "$mountpoint/file";

    assert_script_run "mkdir $mountpoint";
    assert_script_run "chgrp disk $mountpoint";
    assert_script_run "chmod 777 $mountpoint";

    assert_script_run "mkfs.btrfs -f $device";
    assert_script_run "mount -t btrfs $device $mountpoint";

    assert_script_run "dd if=/dev/urandom of=$file bs=1M count=16";
    assert_script_run "md5sum $file > $md5";
    assert_script_run "cp $file $file_copy";

    # unmount and flush slab and page cache
    assert_script_run "umount $mountpoint";
    assert_script_run "echo 3 > /proc/sys/vm/drop_caches";

    # remount and check md5sum
    assert_script_run "mount -t btrfs $device $mountpoint";
    assert_script_run "cd $mountpoint; md5sum -c $md5; cd /";

    assert_script_run("umount $mountpoint");

    if (zypper_search('lklfuse')) {
        assert_script_run "useradd -m -G users,disk unpriv -p $testapi::password";
        install_package 'lklfuse';
        script_start_io('su unpriv');
        my $script = <<"FIN";
dd if=/dev/urandom of=/home/unpriv/file2 bs=1M count=16
md5sum /home/unpriv/file2 > /home/unpriv/md5
mkdir -p /home/unpriv/mount
lklfuse -o type=btrfs $device /home/unpriv/mount
cp /home/unpriv/file2 /home/unpriv/mount/file2
fusermount -u /home/unpriv/mount
sync
lklfuse -o type=btrfs $device /home/unpriv/mount
cd /home/unpriv/mount; md5sum -c /home/unpriv/mount/md5; cd
FIN
        assert_script_run($script);
        script_finish_io();
        enter_cmd('exit');
    } elsif (is_sle('16+')) {
        die "running on SLE16+ but lklfuse package is missing";
    }

    # cleanup
    assert_script_run("rm -r $tmp");
}

sub test_flags {
    return {fatal => 0};
}

1;
