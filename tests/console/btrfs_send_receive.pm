# SUSE's openQA tests
#
# Copyright © 2016-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Btrfs send & receive snapshots
# Maintainer: mkravec <mkravec@suse.com>

use base 'btrfs_test';
use strict;
use warnings;
use testapi;
use utils;

my $src  = "/root/sr";
my $dest = "/mnt/sr";

sub generate_data {
    assert_script_run "cd $src/sv";
    assert_script_run "for i in {1..100}; do dd if=/dev/urandom bs=1M count=1 of=file\$i; done";
}

sub shuffle_data {
    assert_script_run "cd $src/sv";
    assert_script_run "ls | shuf -n 5 | xargs rm -v";
    assert_script_run "ls | shuf -n 20 | xargs -I {} dd if=/dev/urandom of={} bs=2M count=1";
    assert_script_run "ls | shuf -n 20 | xargs chmod -v \$((\$RANDOM % 8))\$((\$RANDOM % 8))\$((\$RANDOM % 8))";
}

sub compare_data {
    my $num = shift;

    assert_script_run "cd $src/sv";
    my $sum_orig = script_output "find | LC_ALL=C sort | pax -w -d | md5sum";

    assert_script_run "cd $dest/snap$num";
    my $sum_snap = script_output "find | LC_ALL=C sort | pax -w -d | md5sum";

    die "Data differ" unless $sum_orig eq $sum_snap;
}

# poo#11792
sub run {
    my ($self) = @_;
    select_console 'root-console';

    # Set up
    assert_script_run "mkdir $src";
    assert_script_run "btrfs subvolume create $src/sv";
    assert_script_run "mkdir $dest";
    $self->set_playground_disk;
    my $disk = get_required_var('PLAYGROUNDDISK');
    assert_script_run "mkfs.btrfs -f $disk && mount $disk $dest";
    #make sure that pax is installed
    zypper_call('in -C pax');

    # Create full snapshot
    generate_data;
    assert_script_run "btrfs subvolume snapshot -r $src/sv $src/snap1";
    assert_script_run "btrfs send $src/snap1 | btrfs receive $dest";
    compare_data 1;

    # Create few incremental snapshots
    for my $i (2 .. 3) {
        shuffle_data;
        assert_script_run "btrfs subvolume snapshot -r $src/sv $src/snap$i";
        assert_script_run "btrfs send -p $src/snap" . ($i - 1) . " $src/snap$i | btrfs receive $dest";
        compare_data $i;
    }
    assert_script_run "umount -l $disk";
    $self->cleanup_partition_table;
}

1;
