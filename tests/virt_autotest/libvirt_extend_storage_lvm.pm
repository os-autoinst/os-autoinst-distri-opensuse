# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Virtualization Extend LVM Storage pool / volume test
#
# Test flow:
# - Check a additional free hard disk
# - Wipe hard disk clean
# - Partition test disk
# - Create a pv and display result
# - Create a vg named 'lvm_vg' and display result
# - Create a storage pool (lv) named 'guest_image_lvm'
# - Create a logical volume (lv) size 1G
# - Attach a logical volume (lv) to guest systems
# - Clone a logical volume (lv)
# - Cleanup
# Maintainer: Leon Guo <xguo@suse.com>

use base "virt_feature_test_base";
use virt_autotest::virtual_storage_utils;
use virt_autotest::utils;
use virt_autotest::common;
use strict;
use warnings;
use testapi;
use utils;
use virt_utils;
use version_utils 'is_sle';

our $lvm_vg_name = 'lvm_vg';
our $lvm_pool_name = 'guest_image_lvm';
sub run_test {
    my ($self) = @_;

    record_info "Prepare Guest Systems";
    foreach (keys %virt_autotest::common::guests) {
        start_guests() unless is_guest_online($_);
    }
    ## Prepare Virtualization LVM Storage Pool Source
    my ($lvm_disk, $lvm_return) = $self->prepare_lvm_storage_pool_source();
    return if ($lvm_return == 1);

    ## About LVM volume group storage pool management
    # Use an LVM Volume Group (VG) as a storage pool named 'guest_image_lvm'
    record_info "LVM Storage Pool define";
    assert_script_run "virsh pool-define-as $lvm_pool_name logical --source-name $lvm_vg_name --target /dev/lvm_vg";
    # Basic Virtualization LVM Storage Management
    my $lvm_vol_size = '1G';
    virt_storage_management($lvm_pool_name, size => $lvm_vol_size);

    ## Cleanup
    # Destroy the LVM volume group storage pool
    destroy_virt_storage_pool($lvm_pool_name, lvm => 1, lvmdisk => $lvm_disk);
}

# Prepare Virtualization LVM Storage Pool source
sub prepare_lvm_storage_pool_source {
    ## Physical Hard Disk preparation
    # Check with all existed Hard disks
    my ($dev, $lvm_disk_name);
    my @disks = split(/\n/, script_output("lsblk -n -l -o NAME -d -e 7,11"));
    my $scalar = @disks;
    my $ret = 0;
    #NOTE: Requires at least 2 physical hard disks for LVM Storage test
    if (($scalar eq 1) || get_var('KEEP_DISKS')) {
        record_info("WARNING", "Requires at least 2 physical hard disks for LVM Storage test\n", result => 'softfail');
        $ret = 1;
    }
    # Use a unused hard disk for LVM volumes
    $dev = "/dev/";
    foreach my $disk (@disks) {
        if (script_run("set -o pipefail;lsblk -rnoPKNAME,MOUNTPOINT | grep -i $disk | awk \'{print \$2}\'") ne '0') {
            $lvm_disk_name = $dev . $disk;
            last;
        }
    }
    record_info "Assign a New Disk:", "$lvm_disk_name";
    # Wipe Hard Disk Clean via dd for assigned a new full disk
    wipe_hard_disk($lvm_disk_name);
    ## About LVM volumes management
    # Create a Volume Group (VG) with LVM named 'lvm_vg'
    create_volume_group($lvm_disk_name);
    return ($lvm_disk_name,$ret);
}

# Wipe Hard Disk Clean via dd
sub wipe_hard_disk {
    my $hard_disk_name = shift;
    assert_script_run("dd if=/dev/zero of=$hard_disk_name count=1M", timeout => 1500, fail_message => "Failed to wipe hard disk clean on $hard_disk_name");
}

# Create a Volume Group with LVM
sub create_volume_group {
    my $lvm_disk_name = shift;
    my $timeout = 180;
    # Create new disk partition for LVM volumes
    record_info "Create new disk partition for LVM volumes";
    assert_script_run 'echo -e "g\nn\n\n\n+20G\nt\n8e\np\nw" | fdisk ' . $lvm_disk_name;
    # Create a Physical Volume (PV) with LVM
    record_info "Create a Physical Volume";
    validate_script_output("pvcreate ${lvm_disk_name}1", sub { m/successfully created/ }, $timeout);
    validate_script_output("pvdisplay", sub { m/${lvm_disk_name}1/ }, $timeout);
    # Create a Volume Group (VG) with LVM named 'lvm_vg'
    record_info "Create a Volume Group";
    validate_script_output("vgcreate $lvm_vg_name ${lvm_disk_name}1", sub { m/successfully created/ }, $timeout);
    validate_script_output("vgdisplay ${lvm_vg_name}", sub { m/${lvm_vg_name}/ }, $timeout);
    save_screenshot;
}

1;
