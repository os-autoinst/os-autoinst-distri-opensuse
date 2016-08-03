# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "consoletest";
use strict;
use testapi;

my $dest = "/mnt/qg";

# poo#11446
# Creating qgroups in a hierarchy for multiple subvolumes,
# putting data into them and then running btrfsck on the hard disk
sub run() {
    select_console 'root-console';

    # Set up
    assert_script_run "mkdir $dest";
    assert_script_run "mkfs.btrfs -f /dev/vdb && mount /dev/vdb $dest && cd $dest";
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
    assert_script_run "for c in {1..40};  do dd if=/dev/zero bs=1M count=1 of=a/file\$c; done";
    assert_script_run "for c in {1..40};  do dd if=/dev/zero bs=1M count=1 of=b/file\$c; done";
    assert_script_run "for c in {1..200}; do dd if=/dev/zero bs=1M count=1 of=c/file\$c; done";
    assert_script_run "for c in {1..150}; do dd if=/dev/zero bs=1M count=1 of=d/file\$c; done";

    assert_script_run "btrfs subvolume snapshot d k";
    assert_script_run "btrfs quota rescan -w .";
    assert_script_run "rm d/file\[1-75\]";
    assert_script_run "for c in {51..100}; do dd if=/dev/zero bs=1M count=1 of=k/file\$c; done";

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

    assert_script_run "cd; umount $dest";
    assert_script_run "btrfsck /dev/vdb";
}

sub test_flags() {
    return {important => 1};
}

1;
