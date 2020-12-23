# SUSE's openQA tests
#
# Copyright © 2018-2020 SUSE LLC
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
use filesystem_utils qw(str_to_mb parted_print partition_num_by_type mountpoint_to_partition
  partition_table create_partition remove_partition format_partition);

my $INST_DIR    = '/opt/xfstests';
my $CONFIG_FILE = "$INST_DIR/local.config";

# Number of SCRATCH disk in SCRATCH_DEV_POOL, other than btrfs has only 1 SCRATCH_DEV, xfstests specific
sub partition_amount_by_homesize {
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
    else {
        print "Info: Current HDD file don't have a /home partition.";
    }
    return %ret;
}

# Do partition by giving inputs
# Inputs explain
# $filesystem: filesystem type
# $amount: Amount of partitions to be created for SCRATCH_DEV. Available for btrfs, at most 5.
# $size: Size of each partition size for TEST_DEV and SCRATCH_DEV. Default: 5120
# $dev: Optional. Device to be partitioned. Default: same device as root partition
# $delhome: Delete home partition to get free space for test partition.
sub do_partition_for_xfstests {
    my $ref  = shift;
    my %para = %{$ref};
    my ($part_table, $part_type, $test_dev);
    unless ($para{size}) {
        $para{size} = 5120;
    }
    unless ($para{amount}) {
        $para{amount} = 1;
    }
    if ($para{fstype} =~ /btrfs/ && $para{amount} > 5) {
        $para{amount} = 5;
    }
    else {
        # Mandatory xfs and ext4 has only 1 SCRATCH_DEV
        $para{amount} = 1;
    }
    unless (exists($para{dev})) {
        my $part = mountpoint_to_partition('/');
        if ($part =~ /(.*?)(\d+)/) {
            $para{dev} = $1;
        }
    }
    if (exists($para{delhome}) && $para{delhome} != 0) {
        my $part = mountpoint_to_partition('/home');
        remove_partition($part);
        script_run("sed -i -e '/ \/home /d' /etc/fstab");
        script_run('mkdir /home/fsgqa; mkdir /home/fsgqa-123456');
    }
    parted_print($para{dev});
    # Prepare suitable partition type, if don't have extended then create one
    $part_table = partition_table($para{dev});
    if ($part_table =~ 'msdos') {
        $part_type = 'logical';
    }
    else {
        $part_type = 'primary';
    }
    if ($part_table =~ 'msdos' && partition_num_by_type($para{dev}, 'extended') == -1) {
        create_partition($para{dev}, 'extended', 'max');
        parted_print($para{dev});
    }
    # Create TEST_DEV
    $test_dev = create_partition($para{dev}, $part_type, $para{size});
    parted_print($para{dev});
    format_partition($test_dev, $para{fstype});
    # Create SCRATCH_DEV or SCRATCH_DEV_POOL
    my @scratch_dev;
    my $num = $para{amount};
    while ($num != 0) {
        $num -= 1;
        my $part = create_partition($para{dev}, $part_type, $para{size});
        format_partition($part, $para{fstype});
        push @scratch_dev, $part;
    }
    parted_print($para{dev});
    # Create mount points
    script_run('mkdir /mnt/test /mnt/scratch');
    # Setup configure file xfstests/local.config
    script_run("echo 'export TEST_DEV=$test_dev' >> $CONFIG_FILE");
    set_var('XFSTESTS_TEST_DEV', $test_dev);
    script_run("echo 'export TEST_DIR=/mnt/test' >> $CONFIG_FILE");
    script_run("echo 'export SCRATCH_MNT=/mnt/scratch' >> $CONFIG_FILE");
    if ($para{amount} == 1) {
        script_run("echo 'export SCRATCH_DEV=$scratch_dev[0]' >> $CONFIG_FILE");
        set_var('XFSTESTS_SCRATCH_DEV', $scratch_dev[0]);
    }
    else {
        my $SCRATCH_DEV_POOL = join(' ', @scratch_dev);
        script_run("echo 'export SCRATCH_DEV_POOL=\"$SCRATCH_DEV_POOL\"' >> $CONFIG_FILE");
        set_var('XFSTESTS_SCRATCH_DEV_POOL', $SCRATCH_DEV_POOL);
    }
    # Sync
    script_run('sync');
}

# Create loop device by giving inputs
# only available when enable XFSTESTS_LOOP_DEVICE in openQA
# Inputs explain
# $filesystem: filesystem type
# $size: Size of each partition size for TEST_DEV and SCRATCH_DEV. Default: 5120
sub create_loop_device_by_rootsize {
    my $ref    = shift;
    my %para   = %{$ref};
    my $amount = 1;
    my ($size, $count, $bsize);
    if ($para{fstype} =~ /btrfs/) {
        $amount = 5;
    }
    # Use 90% of free space, not use all space in /root
    $size  = int($para{size} * 0.9 / ($amount + 1));
    $bsize = 4096;
    $count = int($size * 1024 * 1024 / $bsize);
    my $num = 0;
    my $filename;
    while ($amount >= $num) {
        if ($num) {
            $filename = "scratch_dev$num";
        }
        else {
            $filename = "test_dev";
        }
        assert_script_run("fallocate -l \$(($bsize * $count)) $INST_DIR/$filename", 300);
        assert_script_run("losetup -fP $INST_DIR/$filename",                        300);
        $num += 1;
    }
    script_run("losetup -a");
    format_partition("$INST_DIR/test_dev", $para{fstype});
    # Create mount points
    script_run('mkdir /mnt/test /mnt/scratch');
    # Setup configure file xfstests/local.config
    script_run("echo 'export TEST_DEV=/dev/loop0' >> $CONFIG_FILE");
    set_var('XFSTESTS_TEST_DEV', '/dev/loop0');
    script_run("echo 'export TEST_DIR=/mnt/test' >> $CONFIG_FILE");
    script_run("echo 'export SCRATCH_MNT=/mnt/scratch' >> $CONFIG_FILE");
    if ($amount == 1) {
        script_run("echo 'export SCRATCH_DEV=/dev/loop1' >> $CONFIG_FILE");
        set_var('XFSTESTS_SCRATCH_DEV', '/dev/loop1');
    }
    else {
        script_run("echo 'export SCRATCH_DEV_POOL=\"/dev/loop1 /dev/loop2 /dev/loop3 /dev/loop4 /dev/loop5\"' >> $CONFIG_FILE");
        set_var('XFSTESTS_SCRATCH_DEV_POOL', '/dev/loop1 /dev/loop2 /dev/loop3 /dev/loop4 /dev/loop5');
    }
    # Sync
    script_run('sync');
}

sub set_config {
    my $self = shift;
    script_run("echo 'export KEEP_DMESG=yes' >> $CONFIG_FILE");
}

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    # DO NOT set XFSTESTS_DEVICE if you don't know what's this mean
    # by default we use /home partition spaces for test, and don't need this setting
    my $device  = get_var('XFSTESTS_DEVICE');
    my $loopdev = get_var('XFSTESTS_LOOP_DEVICE');

    my $filesystem = get_required_var('XFSTESTS');
    my %para;
    if ($device) {
        assert_script_run("parted $device --script -- mklabel gpt");
        $para{fstype} = $filesystem;
        $para{dev}    = $device;
        do_partition_for_xfstests(\%para);
    }
    else {
        if ($loopdev) {
            $para{fstype} = $filesystem;
            $para{size}   = script_output("df -h | grep /\$ | awk -F \" \" \'{print \$4}\'");
            $para{size}   = str_to_mb($para{size});
            create_loop_device_by_rootsize(\%para);
        }
        else {
            my $home_size = script_output("df -h | grep home | awk -F \" \" \'{print \$2}\'");
            my %size_num  = partition_amount_by_homesize($home_size);
            $para{fstype}  = $filesystem;
            $para{amount}  = $size_num{num};
            $para{size}    = $size_num{size};
            $para{delhome} = 1;
            do_partition_for_xfstests(\%para);
        }
    }
    set_config;
}

sub test_flags {
    return {fatal => 1};
}

1;
