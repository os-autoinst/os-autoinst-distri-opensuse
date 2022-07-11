# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: virtual_storage_utils:
#          This file provides fundamental utilities for virtual storage.
# Maintainer: Leon Guo <xguo@suse.com>

package virt_autotest::virtual_storage_utils;

use base Exporter;
use Exporter;

use utils;
use strict;
use warnings;
use File::Basename;
use testapi;
use Data::Dumper;
use XML::Writer;
use IO::File;
use proxymode;
use version_utils 'is_sle';
use virt_autotest_base;
use virt_autotest::utils;
use virt_utils;

our @EXPORT
  = qw(virt_storage_management destroy_virt_storage_pool delete_physical_volume);


# Basic Virtualization Storage Management
sub virt_storage_management {
    my ($vstorage_pool_name, %args) = @_;
    my $vol_size = $args{size};
    my $timeout = $args{timeout} // 120;
    my $dir = $args{dir} // 0;
    my $vol_resize = $args{resize} // 0;
    ## Basic Virtualization Storage Pool Management
    record_info "Storage Pool list";
    assert_script_run "virsh pool-list --all | grep $vstorage_pool_name";
    record_info "Storage Pool start";
    assert_script_run "virsh pool-start $vstorage_pool_name";
    record_info "Storage Pool autostart";
    assert_script_run "virsh pool-autostart $vstorage_pool_name";
    record_info "Storage Pool info";
    assert_script_run "virsh pool-info $vstorage_pool_name";

    ## Basic Virtualization Storage Volume Management
    # Create a Storage Volume
    record_info "Create a Storage Volume";
    assert_script_run("virsh vol-create-as $vstorage_pool_name $_-storage $vol_size", $timeout) foreach (keys %virt_autotest::common::guests);
    record_info "List Storage Volumes";
    assert_script_run("virsh vol-list $vstorage_pool_name | grep $_-storage", $timeout) foreach (keys %virt_autotest::common::guests);
    record_info "Dump Storage Volumes in XML";
    assert_script_run("virsh vol-dumpxml --pool $vstorage_pool_name $_-storage", $timeout) foreach (keys %virt_autotest::common::guests);
    if ($dir == 1) {
        record_info "Resize";
        assert_script_run("virsh vol-resize --pool testing $_-storage $vol_resize", $timeout) foreach (keys %virt_autotest::common::guests);
    }
    # Attach a Storage Volume to guest system
    record_info "Attached";
    my $target = (is_xen_host) ? "xvdx" : "vdx";
    assert_script_run("virsh attach-disk --domain $_ --source `virsh vol-path --pool $vstorage_pool_name $_-storage` --target $target", $timeout) foreach (keys %virt_autotest::common::guests);
    # Detach a Storage Volume from guest system
    record_info "Detached";
    assert_script_run("virsh detach-disk $_ $target", $timeout) foreach (keys %virt_autotest::common::guests);
    record_info "Clone";
    assert_script_run("virsh vol-clone --pool $vstorage_pool_name $_-storage $_-clone", $timeout) foreach (keys %virt_autotest::common::guests);
    assert_script_run("virsh vol-info --pool $vstorage_pool_name $_-clone", $timeout) foreach (keys %virt_autotest::common::guests);
    # Delete and Remove a Storage Volume from storage pool
    record_info "Remove";
    assert_script_run("virsh vol-delete --pool $vstorage_pool_name $_-clone", $timeout) foreach (keys %virt_autotest::common::guests);
    assert_script_run("virsh vol-delete --pool $vstorage_pool_name $_-storage", $timeout) foreach (keys %virt_autotest::common::guests);
}

# Destroy Virtualization Storage Pool
sub destroy_virt_storage_pool {
    my ($vstorage_pool_name, %args) = @_;
    my $lvm = $args{lvm} // 0;
    my $lvmdisk = $args{lvmdisk} // 0;
    record_info "Storage Pool destroy";
    assert_script_run "virsh pool-destroy $vstorage_pool_name";
    assert_script_run "virsh pool-delete $vstorage_pool_name";
    assert_script_run "virsh pool-undefine $vstorage_pool_name";
    # Delete a Physical Volume (PV) with LVM
    delete_physical_volume($lvmdisk) if ($lvm == 1);
}

# Delete a Physical Volume (PV) with LVM
sub delete_physical_volume {
    my $lvm_disk_name = shift;
    my $timeout = 180;
    validate_script_output("pvremove -y ${lvm_disk_name}1", sub { m/successfully wiped/ }, $timeout);
    assert_script_run 'pvdisplay';
    save_screenshot;
}

1;
