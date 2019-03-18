# SUSE's openQA tests
#
# Copyright © 2016-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Btrfs quota group limit tests improvements
#	 Creating qgroups in a hierarchy for multiple subvolumes,
#	 putting data into them and then running btrfsck on the hard disk
# Maintainer: mkravec <mkravec@suse.com>

use base 'btrfs_test';
use strict;
use warnings;
use testapi;

my $dest = "/mnt/qg";

# poo#11446
sub run {
    my ($self) = @_;
    select_console 'root-console';

    # Set up
    assert_script_run "mkdir $dest";
    $self->set_playground_disk;
    my $disk = get_required_var('PLAYGROUNDDISK');
    assert_script_run "mkfs.btrfs -f $disk && mount $disk $dest && cd $dest";
    assert_script_run "btrfs quota enable .";

    # Create subvolumes, qgroups, assigns and limits
    #      2/1
    #     /   \
    #   1/1   1/2
    #  /   \ / | \
    # a     b  c  d(k)
    assert_script_run "for c in {a..d}; do btrfs subvolume create \$c; done";
    assert_script_run "for c in 1/1 1/2 2/1; do btrfs qgroup create \$c .; done";

    assert_script_run "for c in a b; do btrfs qgroup assign \$c 1/1 .; done";
    assert_script_run "for c in b c d; do btrfs qgroup assign \$c 1/2 .; done";
    assert_script_run "for c in 1/1 1/2; do btrfs qgroup assign \$c 2/1 .; done";

    # Set limits
    assert_script_run "btrfs qgroup limit 50m a .";
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
    type_string "sync\n";
    type_string "btrfs qgroup show --mbytes -pcre .\n";

    # Check limits
    assert_script_run "dd if=/dev/zero bs=10M count=3 of=nofile";
    foreach my $c ('a' .. 'b') {
        assert_script_run "! cp nofile $c/nofile";
        assert_script_run "sync && rm $c/nofile";
    }
    assert_script_run "cp nofile c/nofile";

    # Check for quota exceeding
    assert_script_run 'btrfs subvolume create e';
    assert_script_run 'btrfs qgroup limit 50m e .';
    my $write_chunk = 'dd if=/dev/zero bs=1M count=40 of=e/file';
    assert_script_run "for c in {1..2}; do $write_chunk; done", fail_message => 'bsc#1019614 overwriting same file should not exceed quota';
    # write some more times to the same file to be sure
    if (script_run("for c in {1..38}; do $write_chunk; done")) {
        record_soft_failure 'bsc#1019614';
    }
    assert_script_run 'sync';
    assert_script_run 'rm e/file', fail_message => 'bsc#993841';
    # test exceeding real quota
    my $files_creation = '! for c in {1..2}; do dd if=/dev/zero bs=1M count=40 of=e/file_$c; done';
    assert_script_run $files_creation;
    if (script_run('rm e/file_*')) {
        record_soft_failure 'bsc#1113042  -- btrfs is not informed to commit transaction';
        assert_script_run 'sync';
        assert_script_run $files_creation;
        assert_script_run 'rm e/file_*';
    }

    assert_script_run "cd; umount $dest";
    assert_script_run "btrfsck $disk";
    $self->cleanup_partition_table;
}

1;
