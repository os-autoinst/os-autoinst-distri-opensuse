# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: btrfs_balance
# Summary: Check btrfs balance for functionality
# - create an un-balanced situation
# - force start balance
# - observe system load and ensure disk layout is balanced
# Maintainer: QE Core <qe-core@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;

sub percent_usage {
    my @output = split "\n", script_output("df --local --sync --output=pcent /mnt/raid");
    my $percent = $output[1];
    chop $percent;    # remove final '%' chr
    return $percent;
}

# return difference in GB between space used on two disks of the same raid volume
# on an ideal, perfect balanced system should be 0
sub balanced_delta {
    my $gb = 1024 * 1024 * 1024;
    my @fs_usage = split "\n", script_output("btrfs filesystem usage -b /mnt/raid|tail -2");
    my @disk_free = map { (split)[1] } @fs_usage;
    return int(abs($disk_free[1] - $disk_free[0]) / $gb);
}


sub create_unbalanced_scenario {
    # make a raid0 volume with only one disk, write some data in it then add another disk to the volume
    assert_script_run "mkfs.btrfs -d raid0 -m raid0 /dev/vdb && mkdir /mnt/raid && mount /dev/vdb /mnt/raid";
    # almost fill up the disk with random data, 4GB at a time
    my $counter = 1;
    while (percent_usage() <= 80)
    {
        assert_script_run "dd if=/dev/random of=/mnt/raid/bigfile$counter.bin bs=4M count=1024";
        $counter++;
    }
    # insert second disk into the raid0 volume, eventually making more space available
    assert_script_run "btrfs device add -f /dev/vdc /mnt/raid";
    record_info("INFO", script_output("btrfs device usage /mnt/raid/"));
}

# force balance on our test mountpoint by tweaking config
sub config_balance_parameters {
    my $cfg_file = '/etc/sysconfig/btrfsmaintenance';
    my @configs = (
        q{'s|BTRFS_BALANCE_MOUNTPOINTS="/"|BTRFS_BALANCE_MOUNTPOINTS="/mnt/raid"|g'},
        q{'s|BTRFS_BALANCE_MUSAGE="3"|BTRFS_BALANCE_MUSAGE="100"|g'},
        q{'s|BTRFS_BALANCE_DUSAGE="5 10"|BTRFS_BALANCE_DUSAGE="100"|g'}
    );
    my $replace = join(" -e", @configs);
    assert_script_run qq{sed -i -e $replace $cfg_file};
}

sub run {
    select_console 'root-console';
    zypper_call 'in -f btrfsmaintenance';
    create_unbalanced_scenario();
    # raid volume should be almost full, because data
    # is still only on one disk and filesystem is not balanced
    config_balance_parameters();
    # try at most N times to rebalance filesystem
    my $retries = 0;
    for (;;) {
        assert_script_run '/usr/share/btrfsmaintenance/btrfs-balance.sh';
        last if balanced_delta() <= 5;    # success, fs balanced
        die "Unable to rebalance filesystem" if $retries++ >= 5;
    }
}

1;
