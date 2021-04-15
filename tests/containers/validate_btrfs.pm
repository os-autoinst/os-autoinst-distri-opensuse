# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test Docker’s btrfs storage driver features for image and container management
# Among these features are block-level operations, thin provisioning, copy-on-write snapshots,
# and ease of administration. You can easily combine multiple physical block devices into a single Btrfs filesystem.
# The scenario illustrates the build of a sle image and then reuse the same Dockerfile to check that
# the thin partitioning are used. Then we check the block subvolumes.
# Finally we test the disk administration filling up the subvolume mounted for the images
# and try to pull another image. With btrfs we should be able to add another disk and be able to
# continue when the docker partition is fulled up.
# Maintainer: qac team <qa-c@suse.de>

use Mojo::Base qw(consoletest);
use testapi;
use containers::runtime;

sub _sanity_test_btrfs {
    my ($rt, $dev_path) = @_;
    my $dockerfile_path = '/root/sle_base_image/docker_build';
    my $btrfs_head      = '/tmp/subvolumes_saved';
    $rt->info(property => 'Driver', value => 'btrfs');
    $rt->build($dockerfile_path, 'huge_image');
    assert_script_run "btrfs fi df $dev_path/btrfs/";
    assert_script_run "ls -td $dev_path/btrfs/subvolumes/* | head -n 1 > $btrfs_head";
    validate_script_output "df -h |grep var", sub { m/\/dev\/vda.+[1-6]\d?%/ };
}

sub _test_btrfs_balancing {
    my ($dev_path) = shift;
    assert_script_run qq(btrfs balance start --full-balance $dev_path), timeout => 900;
    assert_script_run "btrfs fi show $dev_path/btrfs";
    validate_script_output "btrfs fi show $dev_path/btrfs", sub { m/devid\s+2.+20.00G.+10.\d+G.+\/dev\/vdb/ };
}

sub _test_btrfs_thin_partitioning {
    my ($rt, $dev_path) = @_;
    my $dockerfile_path = '/root/sle_base_image/docker_build';
    my $btrfs_head      = '/tmp/subvolumes_saved';
    $rt->build($dockerfile_path, 'thin_image');
    # validate that new subvolume has been created. This should be improved.
    assert_script_run qq{test \$(ls -td $dev_path/btrfs/subvolumes/* | head -n 1) == \$(cat $btrfs_head)};
    validate_script_output "btrfs fi df $dev_path", sub { m/^Data.+total=[12].*GiB, used=\d+.+[KM]iB/ };
}

sub _test_btrfs_device_mgmt {
    my ($rt, $dev_path) = @_;
    my $container  = 'registry.opensuse.org/cloud/platform/stack/rootfs/images/sle15';
    my $btrfs_head = '/tmp/subvolumes_saved';
    record_info "test btrfs";
    script_run("df -h");
    # /var is using its own partition which is size of 10G. Create file in the container
    # enough to fill up the partition up to ~99%
    $rt->up('huge_image', keep_container => 1, cmd => 'fallocate -l 9149000KiB bigfile.txt');
    validate_script_output "df -h --sync|grep var", sub { m/\/dev\/vda.+\s+(9[7-9]|100)%/ };
    # partition should be full
    validate_script_output "btrfs fi df $dev_path", sub { m/^Data.+total=8.*GiB, used=8.*GiB/ };
    # Due to disk space this should fail
    die("pull still works") if ($rt->pull("$container") == 0);
    assert_script_run "btrfs device add /dev/vdb $dev_path";
    assert_script_run "btrfs fi show $dev_path/btrfs";
    validate_script_output "lsblk | grep vdb", sub { m/vdb.+20G/ };
    $rt->pull($container);
    assert_script_run qq{test \$(ls -t $dev_path/btrfs/subvolumes/ | head -n 1) != \$(cat $btrfs_head)};
}

sub run {
    my $docker    = containers::runtime->new(runtime => 'docker');
    my $btrfs_dev = '/var/lib/docker';
    _sanity_test_btrfs($docker, $btrfs_dev);
    _test_btrfs_thin_partitioning($docker, $btrfs_dev);
    _test_btrfs_device_mgmt($docker, $btrfs_dev);
    _test_btrfs_balancing($btrfs_dev);
    $docker->cleanup_system_host;
}

1;
