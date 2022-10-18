# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Install xfstests and prepare secondary disk
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use version_utils qw(is_sle);
use registration qw(add_suseconnect_product get_addon_fullname);
use publiccloud::utils qw(is_azure);
use utils;

# xfstests configuration file, as required by xfstests/run
my $INST_DIR = '/opt/xfstests';
my $CONFIG_FILE = "$INST_DIR/local.config";

# The filesystems repo has different links for different versions now
sub get_filesystem_repo {
    my $version = get_required_var('VERSION');
    # The naming scheme of the filesystems repo depens on the version. See https://download.opensuse.org/repositories/filesystems/
    # For SLE<15-SP3 -     e.g. https://download.opensuse.org/repositories/filesystems/SLE_15_SP1
    # From 15-SP3 onwards: e.g. https://download.opensuse.org/repositories/filesystems/15.3
    if (is_sle("<15-SP3")) {
        $version =~ s/-/_/g;    # Version in repo-path needs an underscore instead of a dash
        return "https://download.opensuse.org/repositories/filesystems/SLE_${version}/";
    } elsif (is_sle(">=15-SP3")) {
        $version =~ s/-SP/./g;    # Unified versions with dot (e.g. 15.3)
        return "https://download.opensuse.org/repositories/filesystems/${version}/";
    } else {
        die "Unsupported version: $version for the filesystems repo";
    }
}

# Check if the given user exists, and if not, add it to the system
sub ensure_user_exists {
    my ($user, $uid) = @_;
    assert_script_run("grep '^${user}:' /etc/passwd || useradd '$user' --uid $uid");
}

# Install requirements
sub install_xfstests {
    my ($repo) = @_;
    zypper_ar($repo, name => "filesystems");    # Add filesystem repository, which contains the xfstests
    if (is_sle) {
        # packagehub is required for dbench (required for e.g. generic/241)
        if (is_azure) {
            add_suseconnect_product(get_addon_fullname('phub'), undef, undef, undef, 300, 1);
        } else {
            add_suseconnect_product(get_addon_fullname('phub'));
        }
    }
    my $packages = "xfsprogs xfsdump btrfsprogs kernel-default xfstests fio";
    $packages .= " dbench" unless (is_sle("<15"));    # dbench is not available on <SLE15
    zypper_call("in $packages");
    assert_script_run('ln -s /usr/lib/xfstests/ /opt/xfstests');    # xfstests/run expects the tests to be in /opt/xfstests
    record_info("xfstests", script_output("rpm -q xfstests"));
    # Ensure users 'nobody' and 'daemon' exists
    ensure_user_exists("nobody", 65534);
    ensure_user_exists("daemon", 2);
    # Create test users (See https://git.kernel.org/pub/scm/fs/xfs/xfstests-dev.git/tree/README)
    assert_script_run("useradd -mU fsgqa");    # Create home directory (-m) and 'fsgqa' group for the user (-U) as well
    assert_script_run("useradd fsgqa2");

    # The following is only required by few tests and there is a chance that users starting with digits won't work
    my $fsgqa_123456 = script_run("useradd 123456-fsgqa") == 0;
    record_info("123456-fsgqa", "error creating 123456-fsgqa user.\nSome tests will not be able to run", result => 'softfail') unless ($fsgqa_123456);
}

# Get the device prefix for partitions of a given device.
# nvme disks require an additional 'p' between device and the partition number ("sda1" vs "nvme0n1p1")
sub partition_prefix {
    my $device = $_[0];
    return ($device =~ "nvme") ? "${device}p" : $device;
}

# Format the additional disk and mount it
sub partition_disk {
    my ($device, $mnt_xfs, $mnt_scratch) = @_;
    # Create test and scratch partitions, both formatted with xfs and mounted to the given mountpoints
    assert_script_run("parted $device --script -- mklabel gpt");
    assert_script_run("parted -s -a min $device mkpart primary 1MB 50%");
    assert_script_run("parted -s -a min $device mkpart primary 50% 100%");
    my $part = partition_prefix($device);
    # Note: Each test run creates a new xfs filesystem and mounts it to the given mount point (See create_config),
    # so we don't need to mount the new devices here. We create a new filesystem to ensure, that this is safe to do
    assert_script_run("mkfs.xfs -L xfstests ${part}1");
    assert_script_run("mkfs.xfs -L scratch ${part}2");
    assert_script_run("mkdir -p $mnt_xfs $mnt_scratch");
}

# Create configuration files required for the xfstests suite
sub create_config {
    my ($device, $mnt_xfs, $mnt_scratch) = @_;
    my $part = partition_prefix($device);

    ## Version required by xfstests/partition.pm
    # note: rpm -qa only prints installed packages, and ignores not present ones (e.g. dbench on SLES12-SP4)
    script_run('(rpm -qa xfsprogs xfsdump btrfsprogs kernel-default xfstests dbench; uname -r; rpm -qi kernel-default) | tee /opt/version.log');

    ## Profile config file containing device and mount point definitions
    assert_script_run("echo 'export TEST_DIR=$mnt_xfs' >> $CONFIG_FILE");
    assert_script_run("echo 'export SCRATCH_MNT=$mnt_scratch' >> $CONFIG_FILE");
    assert_script_run("echo 'export TEST_DEV=${part}1' >> $CONFIG_FILE");
    assert_script_run("echo 'export SCRATCH_DEV=${part}2' >> $CONFIG_FILE");
    # Add optional mkfs options
    my $mkfs_options = get_var('XFS_MKFS_OPTIONS', '');
    $mkfs_options .= " -m reflink=1" if (get_var('XFS_TESTS_REFLINK', 0) == 1);
    $mkfs_options =~ s/^\s+|\s+$//g;    # trim string (left and right)
    assert_script_run("echo 'MKFS_OPTIONS=\"$mkfs_options\"' >> $CONFIG_FILE") unless ($mkfs_options eq '');
}

# Get all disks and partitions and return the first device, which has no parititons
sub get_unused_nvme_device {
    my @disks = split /\n/, script_output('lsblk | grep disk | cut -d " " -f1');
    my @parts = split /\n/, script_output('lsblk | grep part | cut -d " " -f1');
    foreach my $disk (@disks) {
        # smartmatch is still experimental, but this can be enabled in the near future.
        #return "/dev/$disk" unless ($disk ~~ @parts);
        return "/dev/$disk" unless (grep { m/$disk/ } @parts);
    }
    die "No unused nvme device available";
}

sub run {
    my $self = shift;
    my $device = get_var("XFS_TEST_DEVICE", "/dev/sdb");
    my $mnt_xfs = "/mnt/xfstests/xfs";
    my $mnt_scratch = "/mnt/scratch";
    select_serial_terminal;

    record_info("lsblk", script_output("lsblk"));    # debug output

    # Special 'nvme' device name means get the first not-used nvme disk.
    # This is necessary on EC2-ARM instances, where the secondary nvme system disk is not predictable (can be nvme0n1 or nvme1n1)
    if ($device eq "nvme") {
        $device = get_unused_nvme_device();
        record_info("nvme disk", "Using '$device' as xfs test device");
    }

    assert_script_run("stat $device", fail_message => "XFS_TEST_DEVICE '$device' does not exists");    # Ensure the given device exists

    install_xfstests(get_filesystem_repo());
    partition_disk($device, $mnt_xfs, $mnt_scratch);
    create_config($device, $mnt_xfs, $mnt_scratch);
    script_run("source $CONFIG_FILE");
}

1;
