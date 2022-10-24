# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test Docker’s btrfs storage driver features for image and container management
# Among these features are block-level operations, thin provisioning, copy-on-write snapshots,
# and ease of administration. You can easily combine multiple physical block devices into a single Btrfs filesystem.
# The scenario illustrates the build of a sle image and then reuse the same Dockerfile to check that
# the thin partitioning are used. Then we check the block subvolumes.
# Finally we test the disk administration filling up the subvolume mounted for the images
# and try to pull another image. With btrfs we should be able to add another disk and be able to
# continue when the docker partition is fulled up.
# Maintainer: qac team <qa-c@suse.de>

use Mojo::Base 'containers::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use containers::common;

# Get the total and used GiB of a given btrfs device
sub _btrfs_fi {
    my $dev = shift;
    my $output = script_output("btrfs fi df $dev");
    die "Unexpected btrfs fi output" unless ($output =~ "^Data.+total=(?<total>[0-9]+\.[0-9]*)GiB, used=(?<used>[0-9]+\.[0-9]*)GiB");
    return ($+{total}, $+{used});
}

sub _sanity_test_btrfs {
    my ($rt, $dev_path, $img) = @_;
    my $dockerfile_path = "~/sle_base_image/docker_build";
    if (script_run("test -d $dockerfile_path") != 0) {
        script_run "mkdir -p $dockerfile_path";
    }
    assert_script_run("echo -e 'FROM $img\\nENV WORLD_VAR Arda' > $dockerfile_path/Dockerfile");
    my $btrfs_head = '/tmp/subvolumes_saved';
    $rt->info(property => 'Driver', value => 'btrfs');
    $rt->build($dockerfile_path, 'huge_image');
    assert_script_run "btrfs fi df $dev_path/btrfs/";
    assert_script_run "ls -td $dev_path/btrfs/subvolumes/* | head -n 1 > $btrfs_head";
    # Ensure the var partition has at least 10% free space
    validate_script_output "df -h | grep var", sub { m/\/dev\/x?[v,s]d[a-z].+ [1-8]?[0-9]%/ };
}

sub _test_btrfs_balancing {
    my ($dev_path) = shift;
    # use -dusage and -musage to prevent "No space left on device" errors, see https://www.suse.com/support/kb/doc/?id=000019789
    assert_script_run qq(btrfs balance start --full-balance -dusage=0 -musage=0 $dev_path), timeout => 900;
    assert_script_run "btrfs fi show $dev_path/btrfs";
    validate_script_output "btrfs fi show $dev_path/btrfs", sub { m/devid\s+2.+20.00G.+[0-9]+.\d+G.+\/dev\/vdb/ };
}

sub _test_btrfs_thin_partitioning {
    my ($rt, $dev_path) = @_;
    my $dockerfile_path = '~/sle_base_image/docker_build';
    my $btrfs_head = '/tmp/subvolumes_saved';
    $rt->build($dockerfile_path, 'thin_image');
    # validate that new subvolume has been created. This should be improved.
    assert_script_run qq{test \$(ls -td $dev_path/btrfs/subvolumes/* | head -n 1) == \$(cat $btrfs_head)};
    validate_script_output "btrfs fi df $dev_path", sub { m/^Data.+total=[1-9].*[KMG]iB, used=\d+.+[KMG]iB/ };
}

# Fill up the btrfs subvolume, check if it is full and then increase the available size by adding another disk
sub _test_btrfs_device_mgmt {
    my ($rt, $dev_path) = @_;
    my $container = 'registry.opensuse.org/cloud/platform/stack/rootfs/images/sle15';
    my $btrfs_head = '/tmp/subvolumes_saved';
    record_info "test btrfs";
    script_run("df -h");
    # Determine the remaining size of /var
    my $var_free = script_output('df 2>/dev/null | grep /var | awk \'{print $4;}\'');
    my $var_blocks = script_output('df 2>/dev/null | grep /var | awk \'{print $2;}\'');
    # Create file in the container enough to fill the "/var" partition (where the container is located)
    my $fill = int($var_free * 1024 * 0.99);    # df returns the size in KiB
    $rt->run_container('huge_image', keep_container => 1, cmd => "fallocate -l $fill bigfile.txt");
    validate_script_output "df -h --sync|grep var", sub { m/\/dev\/vda.+\s+(9[7-9]|100)%/ };
    # check if the partition is full
    my ($total, $used) = _btrfs_fi("/var");
    die "partition should be full" unless (int($used) >= int($total * 0.99));
    die("pull should fail on full partition") if ($rt->pull($container, timeout => 600, die => 0) == 0);
    # Increase the amount of available storage by adding the second HDD ('/dev/vdb') to the pool
    assert_script_run "btrfs device add /dev/vdb $dev_path";
    assert_script_run "btrfs fi show $dev_path/btrfs";
    validate_script_output "lsblk | grep vdb", sub { m/vdb.+[2-9][0-9]G/ };
    my $var_blocks_after = script_output('df 2>/dev/null | grep /var | awk \'{print $2;}\'');
    record_info("btrfs blocks", "before adding vdb: $var_blocks\nafter: $var_blocks_after");
    die "available number of block didn't increase" if ($var_blocks >= $var_blocks_after);
    $rt->pull($container, timeout => 600);
    assert_script_run qq{test \$(ls -t $dev_path/btrfs/subvolumes/ | head -n 1) != \$(cat $btrfs_head)};
}

sub run {
    my ($self) = @_;
    select_serial_terminal;
    die "Module requires two disks to run" unless check_var('NUMDISKS', 2);
    my $docker = $self->containers_factory('docker');
    my $btrfs_dev = '/var/lib/docker';
    my $images_to_test = 'registry.opensuse.org/opensuse/leap:15';
    _sanity_test_btrfs($docker, $btrfs_dev, $images_to_test);
    _test_btrfs_thin_partitioning($docker, $btrfs_dev);
    _test_btrfs_device_mgmt($docker, $btrfs_dev);
    _test_btrfs_balancing($btrfs_dev);
    $docker->cleanup_system_host;
}

sub post_fail_hook {
    my $self = shift;
    script_run "rm -rf ~/sle_base_image/docker_build";
    $self->SUPER::post_fail_hook;
}

sub post_run_hook {
    my $self = shift;
    script_run "rm -rf ~/sle_base_image/docker_build";
    $self->SUPER::post_run_hook;
}

1;
