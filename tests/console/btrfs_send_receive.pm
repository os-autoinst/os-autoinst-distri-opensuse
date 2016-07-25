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

my $src  = "/root/sr";
my $dest = "/mnt/sr";

sub generate_data {
    script_run "cd $src/sv";
    script_run "for i in {1..100}; do dd if=/dev/urandom bs=1M count=1 of=file\$i; done";
}

sub shuffle_data {
    script_run "cd $src/sv";
    script_run "ls | shuf -n 5 | xargs rm -v";
    script_run "ls | shuf -n 20 | xargs -I {} dd if=/dev/urandom of={} bs=2M count=1";
    script_run "ls | shuf -n 20 | xargs chmod -v \$((\$RANDOM % 8))\$((\$RANDOM % 8))\$((\$RANDOM % 8))";
}

sub compare_data {
    my $num = shift;

    script_run "cd $src/sv";
    my $sum_orig = script_output "find | LC_ALL=C sort | pax -w -d | md5sum";

    script_run "cd $dest/snap$num";
    my $sum_snap = script_output "find | LC_ALL=C sort | pax -w -d | md5sum";

    die "Data differ" unless $sum_orig eq $sum_snap;
}

# poo#11792
sub run() {
    select_console 'root-console';

    # Set up
    script_run "mkdir $src";
    script_run "btrfs subvolume create $src/sv";
    script_run "mkdir $dest";
    script_run "mkfs.btrfs /dev/vdb && mount /dev/vdb $dest";

    # Create full snapshot
    generate_data;
    script_run "btrfs subvolume snapshot -r $src/sv $src/snap1";
    script_run "btrfs send $src/snap1 | btrfs receive $dest";
    compare_data 1;

    # Create few incremental snapshots
    for my $i (2 .. 3) {
        shuffle_data;
        script_run "btrfs subvolume snapshot -r $src/sv $src/snap$i";
        script_run "btrfs send -p $src/snap" . ($i - 1) . " $src/snap$i | btrfs receive $dest";
        compare_data $i;
    }
}

sub test_flags() {
    return {important => 1};
}

1;
