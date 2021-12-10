# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Install xfstests and prepare secondary disk
# Maintainer: qa-c team <qa-c@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use version_utils qw(is_sle);
use registration qw(add_suseconnect_product get_addon_fullname);
use utils;

# xfstests configuration file, as required by xfstests/run
my $INST_DIR = '/opt/xfstests';
my $CONFIG_FILE = "$INST_DIR/local.config";

# Check if the given user exists, and if not, add it to the system
sub ensure_user_exists {
    my ($user, $uid) = @_;
    assert_script_run("grep '^${user}:' /etc/passwd || useradd '$user' --uid $uid");
}

# Install requirements
sub install_xfstests {
    my ($repo) = @_;
    zypper_ar($repo, name => "filesystems");    # Add filesystem repository, which contains the xfstests
    add_suseconnect_product(get_addon_fullname('phub')) if is_sle;    # packagehub is required for dbench (required for e.g. generic/241)
    zypper_call('in xfsprogs xfsdump btrfsprogs kernel-default xfstests fio dbench');
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

# Format the additional disk and mount it
sub partition_disk {
    my ($device, $mnt_xfs, $mnt_scratch) = @_;
    # Create test and scratch partitions, both formatted with xfs and mounted to the given mountpoints
    assert_script_run("parted $device --script -- mklabel gpt");
    assert_script_run("parted -s -a min $device mkpart primary 1MB 50%");
    assert_script_run("parted -s -a min $device mkpart primary 50% 100%");
    # Note: Each test run creates a new xfs filesystem and mounts it to the given mount point (See create_config),
    # so we don't need to mount the new devices here. We create a new filesystem to ensure, that this is safe to do
    assert_script_run("mkfs.xfs -L xfstests ${device}1");
    assert_script_run("mkfs.xfs -L scratch ${device}2");
    assert_script_run("mkdir -p $mnt_xfs $mnt_scratch");
}

# Create configuration files required for the xfstests suite
sub create_config {
    my ($device, $mnt_xfs, $mnt_scratch) = @_;

    ## Version required by xfstests/partition.pm
    script_run('(rpm -qa xfsprogs xfsdump btrfsprogs kernel-default xfstests dbench; uname -r; rpm -qi kernel-default) | tee /opt/version.log');

    ## Profile config file containing device and mount point definitions
    assert_script_run("echo 'export TEST_DIR=$mnt_xfs' >> $CONFIG_FILE");
    assert_script_run("echo 'export SCRATCH_MNT=$mnt_scratch' >> $CONFIG_FILE");
    assert_script_run("echo 'export TEST_DEV=${device}1' >> $CONFIG_FILE");
    assert_script_run("echo 'export SCRATCH_DEV=${device}2' >> $CONFIG_FILE");
    # Add optional mkfs options
    my $mkfs_options = get_var('XFS_MKFS_OPTIONS', '');
    $mkfs_options .= " -m reflink=1" if (get_var('XFS_TESTS_REFLINK', 0) == 1);
    $mkfs_options =~ s/^\s+|\s+$//g;    # trim string (left and right)
    assert_script_run("echo 'MKFS_OPTIONS=\"$mkfs_options\"' >> $CONFIG_FILE") unless ($mkfs_options eq '');
}


sub run {
    my $self = shift;
    my $device = get_var("XFS_TEST_DEVICE", "/dev/sdb");
    my $mnt_xfs = "/mnt/xfstests/xfs";
    my $mnt_scratch = "/mnt/scratch";
    $self->select_serial_terminal;

    record_info("lsblk", script_output("lsblk"));    # debug output
    assert_script_run("stat $device", fail_message => "XFS_TEST_DEVICE '$device' does not exists");    # Ensure the given device exists

    my $version = get_required_var('VERSION');
    $version =~ s/-/_/g;    # Version in repo-path needs an underscore instead of a dash
    install_xfstests("https://download.opensuse.org/repositories/filesystems/SLE_${version}/");
    partition_disk($device, $mnt_xfs, $mnt_scratch);
    create_config($device, $mnt_xfs, $mnt_scratch);
    script_run("source $CONFIG_FILE");
}

1;
