# SUSE's openQA tests
#
# Copyright 2016-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: btrfsprogs
# Summary: Btrfs quota group limit tests improvements
#	 Creating qgroups in a hierarchy for multiple subvolumes,
#	 putting data into them and then running btrfsck on the hard disk
# - Call set_playground_disk (Return a disk without a partition table)
# - Create a btrfs filesystem on it, mounts the disk and change to mount point
# - Enable quota in filesystem
# - Create subvolumes, qgroups, assigns, set limits, fill with data
# - Create a test file, copy and sync to test limits
# - Check quota limits (single file, overwrite existing file)
# - Test exceeding real quota
# - Umount test filesystem; check filesystem for btrfs errors, erase partition
# table.
# Maintainer: mkravec <mkravec@suse.com>

use base 'btrfs_test';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';

my $dest = "/mnt/qg";

# poo#11446
sub run {
    my ($self) = @_;
    select_serial_terminal;

    # Set up
    assert_script_run "mkdir $dest";
    $self->set_playground_disk;
    my $disk = get_required_var('PLAYGROUNDDISK');

    # forcing mkfs.btrfs yields no warning in case we are creating fs over drive with partitions
    if (script_run "mkfs.btrfs $disk && mount $disk $dest && cd $dest") {
        $self->cleanup_partition_table;
        assert_script_run "mkfs.btrfs $disk && mount $disk $dest && cd $dest", fail_message => 'Failed to create FS on the second attempt!';
    }

    assert_script_run "btrfs quota enable .";

    # Create subvolumes, qgroups, assigns and limits
    #      2/1
    #     /   \
    #   1/1   1/2
    #  /   \ / | \
    # a     b  c  d(k)
    assert_script_run "for c in {a..d}; do btrfs subvolume create \$c; done";
    assert_script_run "btrfs subvolume list -a $dest";
    assert_script_run "for c in 1/1 1/2 2/1; do btrfs qgroup create \$c .; done";

    assert_script_run "for c in a b; do btrfs qgroup assign $dest/\$c 1/1 .; done";
    assert_script_run "for c in b c d; do btrfs qgroup assign $dest/\$c 1/2 .; done";
    assert_script_run "for c in 1/1 1/2; do btrfs qgroup assign \$c 2/1 .; done";

    # Set limits
    assert_script_run "btrfs qgroup limit 50m $dest/a .";
    assert_script_run "btrfs qgroup limit 100m 1/1 .";
    assert_script_run "btrfs qgroup limit 500m 2/1 .";

    # Fill with data
    assert_script_run "for c in {1..4};  do dd if=/dev/zero bs=1M count=10 of=a/file\$c; done";
    assert_script_run "for c in {1..4};  do dd if=/dev/zero bs=1M count=10 of=b/file\$c; done";
    assert_script_run "for c in {1..20}; do dd if=/dev/zero bs=1M count=10 of=c/file\$c; done";
    assert_script_run "for c in {1..15}; do dd if=/dev/zero bs=1M count=10 of=d/file\$c; done";

    assert_script_run "btrfs subvolume snapshot d k";
    assert_script_run "btrfs quota rescan -w .";
    assert_script_run "rm d/file\[1-7\]";
    assert_script_run "for c in {5..10}; do dd if=/dev/zero bs=1M count=10 of=k/file\$c; done";

    # Show structure
    enter_cmd "sync";
    enter_cmd "btrfs qgroup show --mbytes -pcre .";

    # Check limits
    assert_script_run "dd if=/dev/zero bs=10M count=3 of=nofile";

    # Use the --reflink=never option if it exists
    my $reflink_never = "--reflink=never";
    $reflink_never = "" if script_run('cp --reflink=never /dev/null /tmp/null && rm /tmp/null');

    foreach my $c ('a' .. 'b') {
        assert_script_run "btrfs quota rescan -w .";
        assert_script_run "cp --reflink=always nofile $c/nofile";
        assert_script_run "! cp $reflink_never --remove-destination nofile $c/nofile";
        assert_script_run "sync && rm $c/nofile";
    }
    assert_script_run "cp nofile c/nofile";

    # Check for quota exceeding
    assert_script_run "btrfs subvolume create $dest/e";
    assert_script_run "btrfs qgroup limit 200m $dest/e .";
    my $write_chunk = 'dd if=/dev/zero bs=1M count=190 of=./e/file';
    # Overwriting same file should not exceed quota
    if (script_run("for c in {1..2}; do $write_chunk; done")) {
        record_soft_failure 'File overwrite test: bsc#1113042 - btrfs is not informed to commit transaction';
    }
    # write some more times to the same file to be sure
    if (script_run("for c in {1..38}; do $write_chunk; done", die_on_timeout => 0)) {
        record_soft_failure 'File overwrite test: bsc#1113042 - btrfs is not informed to commit transaction';
    }
    assert_script_run 'sync';
    assert_script_run 'rm ./e/file', fail_message => 'bsc#993841';
    # test exceeding real quota
    my $files_creation = '! for c in {1..2}; do dd if=/dev/zero bs=1M count=190 of=./e/file_$c; done';
    assert_script_run $files_creation, 150;
    if (script_run('rm ./e/file_*')) {
        record_soft_failure 'File removal test: bsc#1113042 - btrfs is not informed to commit transaction';
        assert_script_run 'sync';
        assert_script_run $files_creation, 150;
        assert_script_run 'rm -f ./e/file_*';
    }

    assert_script_run "cd; umount $dest";
    assert_script_run "btrfsck $disk";
    $self->cleanup_partition_table;
}

1;
