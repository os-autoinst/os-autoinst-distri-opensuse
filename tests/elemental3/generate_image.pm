# Copyright 2023-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Test Elemental container image
#   This image is used as a base to build an Elemental container image.
#   Then, that image will be used to build a Host OS on top, so
#   it includes the kernel, firmware, bootloader, etc.
#
# Maintainer: unified-core@suse.com, ldevulder@suse.com

use base 'opensusebasetest';
use strict;
use warnings;

use testapi;
use transactional qw(trup_call);
use serial_terminal qw(select_serial_terminal);
use Mojo::File qw(path);
use utils qw(file_content_replace zypper_call);
use Utils::Architectures qw(is_aarch64);

sub run {
    select_serial_terminal;

    # Variables
    my $arch = get_required_var('ARCH');
    my $build = get_required_var('BUILD');
    my $image = get_required_var('CONTAINER_IMAGE_TO_TEST');
    my $repo_to_test = get_required_var('REPO_TO_TEST');
    my $rootpwd = get_required_var('TEST_PASSWORD');
    my @sysexts = split(',', get_required_var('SYSEXTS'));
    my $img_filename = "elemental-$build-$arch";
    my $shared_dir = '/root/shared';
    my $config_file = "$shared_dir/config.sh";
    my $sysext_root = "$shared_dir/sysexts";
    my $sysext_dir = "$sysext_root/etc/extensions";
    my $overlay = "$shared_dir/sysexts.tar.gz";

    # Define timeouts based on the architecture
    my $timeout = (is_aarch64) ? 480 : 240;

    # Set SELinux in permissive mode, as there is an issue with setfiles
    # It will be removed as soon as the issue will be fixed
    assert_script_run("setenforce Permissive");
    validate_script_output("sestatus | grep 'Current mode:'", sub { m/permissive/ });

    # Create directories
    assert_script_run("mkdir -p $sysext_dir");

    # Add Unified Core repository and install Elemental package
    trup_call("run zypper addrepo --check --refresh $repo_to_test elemental");
    trup_call("--continue run zypper --gpg-auto-import-keys refresh");
    trup_call("--continue pkg install elemental3-toolkit");
    trup_call("apply");

    # OS configuration script
    assert_script_run('curl ' . data_url('elemental3/' . path($config_file)->basename) . ' -o ' . $config_file);
    file_content_replace($config_file, '%TEST_PASSWORD%' => $rootpwd);
    assert_script_run("chmod 755 $config_file");

    # Get the system extensions
    foreach my $sysext (@sysexts) {
        assert_script_run('curl ' . $sysext . " -o $sysext_dir/" . path($sysext)->basename, 300);
    }

    # Package the system extensions
    assert_script_run("tar cvaf $overlay -C $sysext_root .");

    # Create a raw image and mount it as a loop device (forced to 20GB to allow enough space for creating active partition)
    assert_script_run("qemu-img create -f raw $shared_dir/$img_filename.raw 10G");
    my $device = script_output("losetup --find --show $shared_dir/$img_filename.raw");

    # Generate RAW image
    record_info('QCOW2', 'Generate and upload QCOW2 image');
    assert_script_run("elemental3-toolkit --debug install --os-image $image --overlay tar://$overlay --config $config_file --target $device", $timeout);

    # Generate and upload QCOW2 image
    assert_script_run("losetup -d $device");
    assert_script_run("qemu-img convert -c -p -f raw -O qcow2 $shared_dir/$img_filename.raw $shared_dir/$img_filename.qcow2", $timeout);
    upload_asset("$shared_dir/$img_filename.qcow2", 1);
}

sub test_flags {
    return {fatal => 1};
}

1;
