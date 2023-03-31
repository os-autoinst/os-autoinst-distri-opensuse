# SUSE's openQA tests
#
# Copyright 2018-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: parted
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
use serial_terminal 'select_serial_terminal';
use filesystem_utils qw(str_to_mb parted_print partition_num_by_type mountpoint_to_partition
  partition_table create_partition remove_partition format_partition);
use File::Basename;

my $INST_DIR = '/opt/xfstests';
my $CONFIG_FILE = "$INST_DIR/local.config";
my $NFS_VERSION = get_var('XFSTESTS_NFS_VERSION', '4.1');

# Number of SCRATCH disk in SCRATCH_DEV_POOL, other than btrfs has only 1 SCRATCH_DEV, xfstests specific
sub partition_amount_by_homesize {
    my $home_size = shift;
    $home_size = str_to_mb($home_size);
    my %ret;
    if ($home_size && check_var('XFSTESTS', 'btrfs')) {
        # If enough space, then have 5 disks in SCRATCH_DEV_POOL, or have 2 disks in SCRATCH_DEV_POOL
        # At least 8 GB in each SCRATCH_DEV (SCRATCH_DEV_POOL only available for btrfs tests)
        if ($home_size >= 49152) {
            $ret{num} = 5;
            $ret{size} = 1024 * int($home_size / (($ret{num} + 1) * 1024));
            return %ret;
        }
        else {
            $ret{num} = 2;
            $ret{size} = 1024 * int($home_size / (($ret{num} + 1) * 1024));
            return %ret;
        }
    }
    elsif ($home_size) {
        $ret{num} = 1;
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
    my $ref = shift;
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
    parted_print(dev => $para{dev});
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
        parted_print(dev => $para{dev});
    }
    # Create TEST_DEV
    $test_dev = create_partition($para{dev}, $part_type, $para{size});
    parted_print(dev => $para{dev});
    format_with_options($test_dev, $para{fstype});
    # Create SCRATCH_DEV or SCRATCH_DEV_POOL
    my @scratch_dev;
    my $num = $para{amount};
    while ($num != 0) {
        $num -= 1;
        my $part = create_partition($para{dev}, $part_type, $para{size});
        format_partition($part, $para{fstype});
        push @scratch_dev, $part;
    }
    parted_print(dev => $para{dev});
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
    # Create SCRATCH_LOGDEV with disk partition
    if (get_var('XFSTESTS_LOGDEV')) {
        my $logdev = create_partition($para{dev}, $part_type, 1024);
        format_partition($logdev, $para{fstype});
        script_run("echo export SCRATCH_LOGDEV=$logdev >> $CONFIG_FILE");
        script_run("echo export USE_EXTERNAL=yes >> $CONFIG_FILE");
    }
    # Sync
    script_run('sync');
    return $para{size} . 'M';
}

# Create loop device by giving inputs
# only available when enable XFSTESTS_LOOP_DEVICE in openQA
# Inputs explain
# $filesystem: filesystem type
# $size: Size of free space of the rootfs. The size of each TEST_DEV or SCRATCH_DEV is split 90% of $size equally.
sub create_loop_device_by_rootsize {
    my $ref = shift;
    my %para = %{$ref};
    my $amount = 1;
    my ($size, $count, $bsize);
    if ($para{fstype} =~ /btrfs/) {
        $amount = 5;
    }
    # Use 90% of free space, not use all space in /root
    $size = int($para{size} * 0.9 / ($amount + 1));
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
        assert_script_run("losetup -fP $INST_DIR/$filename", 300);
        $num += 1;
    }
    script_run("losetup -a");
    format_with_options("$INST_DIR/test_dev", $para{fstype});
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
    # Create SCRATCH_LOGDEV with loop device
    if (get_var('XFSTESTS_LOGDEV')) {
        my $logdev = "/dev/loop100";
        my $logdev_name = "logdev";

        assert_script_run("fallocate -l 1G $INST_DIR/$logdev_name", 300);
        assert_script_run("losetup -P $logdev $INST_DIR/$logdev_name", 300);
        format_partition("$INST_DIR/$logdev_name", $para{fstype});
        script_run("echo export SCRATCH_LOGDEV=$logdev >> $CONFIG_FILE");
        script_run("echo export USE_EXTERNAL=yes >> $CONFIG_FILE");
    }
    # Sync
    script_run('sync');
    return $size . 'M';
}

sub set_config {
    script_run("echo export KEEP_DMESG=yes >> $CONFIG_FILE");
    if (get_var('XFSTESTS_XFS_REPAIR')) {
        script_run("echo export TEST_XFS_REPAIR_REBUILD=1 >> $CONFIG_FILE");
    }
    if (check_var('XFSTESTS', 'nfs')) {
        script_run("echo export TEST_DEV=localhost:/export/test >> $CONFIG_FILE");
        script_run("echo export TEST_DIR=/nfs/test >> $CONFIG_FILE");
        script_run("echo export SCRATCH_DEV=localhost:/export/scratch >> $CONFIG_FILE");
        script_run("echo export SCRATCH_MNT=/nfs/scratch >> $CONFIG_FILE");
        script_run("echo export NFS_MOUNT_OPTIONS='\"-o rw,relatime,vers=$NFS_VERSION\"' >> $CONFIG_FILE");
    }
    record_info('Config file', script_output("cat $CONFIG_FILE"));
}

sub post_env_info {
    my $size = shift;
    # record version info
    my $ver_log = get_var('VERSION_LOG', '/opt/version.log');
    record_info('Version', script_output("cat $ver_log"));

    # record partition size info
    my $size_info = get_var('XFSTESTS_TEST_DEV') . "    $size\n";
    if (my $scratch_dev = get_var("XFSTESTS_SCRATCH_DEV")) {
        $size_info = $size_info . $scratch_dev . "    $size\n";
    }
    else {
        my @scratch_dev_pool = split(/ /, get_var("XFSTESTS_SCRATCH_DEV_POOL"));
        foreach (@scratch_dev_pool) {
            $size_info = $size_info . $_ . "    $size\n";
        }
    }
    $size_info = $size_info . "PAGE_SIZE    " . script_output("getconf PAGE_SIZE");
    record_info('Size', $size_info);
}

sub format_with_options {
    my ($part, $filesystem) = @_;
    # In case to test different mkfs.xfs options
    if ($filesystem eq 'xfs' && index(get_required_var('TEST'), 'reflink_1024') != -1) {
        format_partition($part, $filesystem, options => '-f -m reflink=1,rmapbt=1, -i sparse=1, -b size=1024');
        script_run("echo 'export XFS_MKFS_OPTIONS=\"-m reflink=1,rmapbt=1, -i sparse=1, -b size=1024\"' >> $CONFIG_FILE");
    }
    elsif ($filesystem eq 'xfs' && index(get_required_var('TEST'), 'reflink_normapbt') != -1) {
        format_partition($part, $filesystem, options => '-f -m reflink=1,rmapbt=0, -i sparse=1');
        script_run("echo 'export XFS_MKFS_OPTIONS=\"-m reflink=1,rmapbt=0, -i sparse=1\"' >> $CONFIG_FILE");
    }
    elsif ($filesystem eq 'xfs' && index(get_required_var('TEST'), 'reflink') != -1) {
        format_partition($part, $filesystem, options => '-f -m reflink=1,rmapbt=1, -i sparse=1');
        script_run("echo 'export XFS_MKFS_OPTIONS=\"-m reflink=1,rmapbt=1, -i sparse=1\"' >> $CONFIG_FILE");
    }
    elsif ($filesystem eq 'xfs' && index(get_required_var('TEST'), 'nocrc_512') != -1) {
        format_partition($part, $filesystem, options => '-f -m crc=0,reflink=0,rmapbt=0, -i sparse=0, -b size=512');
        script_run("echo 'export XFS_MKFS_OPTIONS=\"-m crc=0,reflink=0,rmapbt=0, -i sparse=0, -b size=512\"' >> $CONFIG_FILE");
    }
    elsif ($filesystem eq 'xfs' && index(get_required_var('TEST'), 'nocrc') != -1) {
        format_partition($part, $filesystem, options => '-f -m crc=0,reflink=0,rmapbt=0, -i sparse=0');
        script_run("echo 'export XFS_MKFS_OPTIONS=\"-m crc=0,reflink=0,rmapbt=0, -i sparse=0\"' >> $CONFIG_FILE");
    }
    elsif ($filesystem eq 'xfs' && index(get_required_var('TEST'), 'logdev') != -1) {
        format_partition($part, 'xfs', options => '-f -m crc=1,reflink=0,rmapbt=0, -i sparse=0 -lsize=100m');
        script_run("echo 'export XFS_MKFS_OPTIONS=\"-m crc=1,reflink=0,rmapbt=0, -i sparse=0 -lsize=100m\"' >> $CONFIG_FILE");
    }
    elsif ($filesystem eq 'xfs' && index(get_required_var('TEST'), 'bigtime') != -1) {
        format_partition($part, 'xfs', options => '-f -m bigtime=1');
        script_run("echo 'export XFS_MKFS_OPTIONS=\"-m bigtime=1\"' >> $CONFIG_FILE");
    }
    # In case to test different mkfs.btrfs options
    # $XFSTEST_MKFS_OPTION: options for mkfs.btrfs
    # Example of 4k block size: -f -s 4k -n 16k
    elsif ($filesystem eq 'btrfs' && (my $mkfs_option = get_var('XFSTEST_MKFS_OPTION'))) {
        format_partition($part, 'btrfs', options => "$mkfs_option");
        script_run("echo 'export BTRFS_MKFS_OPTIONS=\"$mkfs_option\"' >> $CONFIG_FILE");
    }
    else {
        format_partition($part, $filesystem);
    }
}

sub install_dependencies_nfs {
    my @deps = qw(
      nfs-client
      nfs-kernel-server
      nfs4-acl-tools
    );
    zypper_call('in ' . join(' ', @deps));
}

sub setup_nfs_server {
    my $nfsversion = shift;
    assert_script_run('mkdir -p /export/test /export/scratch /nfs/test /nfs/scratch && chown nobody:nogroup /export/test /export/scratch && echo \'/export/test *(rw,no_subtree_check,no_root_squash)\' >> /etc/exports && echo \'/export/scratch *(rw,no_subtree_check,no_root_squash,fsid=1)\' >> /etc/exports');

    my $nfsgrace = get_var('NFS_GRACE_TIME', 15);
    assert_script_run("echo 'options lockd nlm_grace_period=$nfsgrace' >> /etc/modprobe.d/lockd.conf && echo 'options lockd nlm_timeout=5' >> /etc/modprobe.d/lockd.conf");

    if ($nfsversion == '3') {
        assert_script_run("echo 'MOUNT_NFS_V3=\"yes\"' >> /etc/sysconfig/nfs");
        assert_script_run("echo 'MOUNT_NFS_DEFAULT_PROTOCOL=3' >> /etc/sysconfig/autofs && echo 'OPTIONS=\"-O vers=3\"' >> /etc/sysconfig/autofs");
        assert_script_run("echo 'Defaultvers=3' >> /etc/nfsmount.conf && echo 'Nfsvers=3' >> /etc/nfsmount.conf");
    }
    else {
        assert_script_run("sed -i 's/NFSV4LEASETIME=\"\"/NFSV4LEASETIME=\"$nfsgrace\"/' /etc/sysconfig/nfs");
        assert_script_run("echo -e '[nfsd]\\ngrace-time=$nfsgrace\\nlease-time=$nfsgrace' > /etc/nfs.conf.local");
    }
    assert_script_run('exportfs -a && systemctl restart rpcbind && systemctl enable nfs-server.service && systemctl restart nfs-server');

    # There's a graceful time we need to wait before using the NFS server
    my $gracetime = script_output('cat /proc/fs/nfsd/nfsv4gracetime;');
    sleep($gracetime * 2);
}

sub run {
    select_serial_terminal;

    # DO NOT set XFSTESTS_DEVICE if you don't know what's this mean
    # by default we use /home partition spaces for test, and don't need this setting
    my $device = get_var('XFSTESTS_DEVICE');
    my $loopdev = get_var('XFSTESTS_LOOP_DEVICE');

    my $filesystem = get_required_var('XFSTESTS');
    my %para;
    if (check_var('XFSTESTS', 'nfs')) {
        install_dependencies_nfs;
        setup_nfs_server("$NFS_VERSION");
    }
    elsif ($device) {
        assert_script_run("parted $device --script -- mklabel gpt");
        $para{fstype} = $filesystem;
        $para{dev} = $device;
        post_env_info(do_partition_for_xfstests(\%para));
    }
    else {
        if ($loopdev) {
            $para{fstype} = $filesystem;
            $para{size} = script_output("df -h | grep /\$ | awk -F \" \" \'{print \$4}\'");
            $para{size} = str_to_mb($para{size});
            post_env_info(create_loop_device_by_rootsize(\%para));
        }
        else {
            my $home_size = script_output("df -h | grep home | awk -F \" \" \'{print \$2}\'");
            my %size_num = partition_amount_by_homesize($home_size);
            $para{fstype} = $filesystem;
            $para{amount} = $size_num{num};
            $para{size} = $size_num{size};
            $para{delhome} = 1;
            post_env_info(do_partition_for_xfstests(\%para));
        }
    }
    set_config;
}

sub test_flags {
    return {fatal => 1};
}

1;
