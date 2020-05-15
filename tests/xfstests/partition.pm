# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Create partitions for xfstests
# - Create a gpt partition table on device
# - Partition device according to system variable XFSTESTS_DEVICE or
# calculated home size
# Maintainer: Yong Sun <yosun@suse.com>
package partition;

use 5.018;
use strict;
use warnings;
use base 'opensusebasetest';
use utils;
use testapi;

sub str_to_mb {
    my $str = shift;
    if ($str =~ /(\d+(\.\d+)?)K/) {
        return $1 / 1024;
    }
    elsif ($str =~ /(\d+(\.\d+)?)M/) {
        return $1;
    }
    elsif ($str =~ /(\d+(\.\d+)?)G/) {
        return $1 * 1024;
    }
    else {
        return;
    }
}

# Number of SCRATCH disk in SCRATCH_DEV_POOL, other than btrfs has only 1 SCRATCH_DEV
sub partition_size_num {
    my $home_size = shift;
    $home_size = str_to_mb($home_size);
    my %ret;
    if ($home_size && check_var('XFSTESTS', 'btrfs')) {
        # If enough space, then have 5 disks in SCRATCH_DEV_POOL, or have 2 disks in SCRATCH_DEV_POOL
        # At least 8 GB in each SCRATCH_DEV (SCRATCH_DEV_POOL only available for btrfs tests)
        if ($home_size >= 49152) {
            $ret{num}  = 5;
            $ret{size} = 1024 * int($home_size / (($ret{num} + 1) * 1024));
            return %ret;
        }
        else {
            $ret{num}  = 2;
            $ret{size} = 1024 * int($home_size / (($ret{num} + 1) * 1024));
            return %ret;
        }
    }
    elsif ($home_size) {
        $ret{num}  = 1;
        $ret{size} = int($home_size / 2);
        return %ret;
    }
    return %ret;
}

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    # Create partitions
    my $filesystem = get_required_var('XFSTESTS');
    my $device     = get_var('XFSTESTS_DEVICE');
    my $home_size  = script_output("df -h | grep home | awk -F \" \" \'{print \$2}\'");
    my %size_num   = partition_size_num($home_size);
    if ($device) {
        assert_script_run("parted $device --script -- mklabel gpt");
        assert_script_run("/usr/share/qa/qa_test_xfstests/partition.py --device $device $filesystem && sync", 600);
    }
    else {
        if (%size_num) {
            assert_script_run("/usr/share/qa/qa_test_xfstests/partition.py --delhome $filesystem -t $size_num{size} -s $size_num{size} -n $size_num{num} && sync", 600);
        }
        else {
            assert_script_run("/usr/share/qa/qa_test_xfstests/partition.py --delhome $filesystem && sync", 600);
        }
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
