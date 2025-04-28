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
use utils qw(zypper_call);

sub run {
    select_serial_terminal;

    my $arch = get_required_var('ARCH');
    my $build = get_required_var('BUILD');
    my $image = get_required_var('CONTAINER_IMAGE_TO_TEST');
    my $repo_to_test = get_required_var('REPO_TO_TEST');
    my $img_filename = "elemental-$build-$arch";
    my $shared = '/var/shared';

    # Create shared directory
    assert_script_run("mkdir -p $shared");

    # Add Unified Core repository and install Elemental package
    trup_call("run zypper addrepo --check --refresh $repo_to_test elemental");
    trup_call("--continue run zypper --gpg-auto-import-keys refresh");
    trup_call("--continue pkg install elemental3-toolkit");
    trup_call("apply");

    # Create a raw image and mount it as a loop device (forced to 20GB to allow enough space for creating active partition)
    assert_script_run("qemu-img create -f raw $shared/$img_filename.raw 20G");
    my $device = script_output("losetup --find --show $shared/$img_filename.raw");

    # Generate and upload QCOW2 image
    record_info('QCOW2', 'Generate and upload QCOW2 image');
    assert_script_run("elemental3-toolkit --debug install --os-image $image --target $device", 300);
    assert_script_run("qemu-img convert -f raw -O qcow2 $shared/$img_filename.raw $shared/$img_filename.qcow2");
    upload_asset("$shared/$img_filename.qcow2", 1);
}

sub test_flags {
    return {fatal => 1};
}

1;
