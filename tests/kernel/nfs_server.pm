# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: NFS server
#    This module provisions the NFS server and then runs some
#    basic sanity tests
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base "opensusebasetest";
use testapi;
use serial_terminal "select_serial_terminal";
use lockapi;
use utils;
use Utils::Logging "export_logs_basic";

sub run {
    select_serial_terminal();

    #TODO: configure nfs config as pleased, specifically:
    #USE_KERNEL_NFSD_NUMBER
    #NFS3_SERVER_SUPPORT
    #NFS4_SUPPORT
    #NFSV4LEASETIME
    #TODO: introduce nfs ha setup

    #TODO: all below folder creation and exports should be abstracted
    #TODO: allow this to be configurable
    my $nfs_mount_nfs3 = "/nfs/shared_nfs3";
    my $nfs_mount_nfs4 = "/nfs/shared_nfs4";
    my $nfs_permissions = "rw,sync,no_root_squash";

    my $nfs_mount_nfs3_async = "/nfs/shared_nfs3_async";
    my $nfs_mount_nfs4_async = "/nfs/shared_nfs4_async";
    my $nfs_permissions_async = "rw,async,no_root_squash";

    # provision NFS server(s) of various types
    zypper_call("in yast2-nfs-server");

    assert_script_run("mkdir -p $nfs_mount_nfs3");
    assert_script_run("chmod 777 $nfs_mount_nfs3");
    assert_script_run("mkdir -p $nfs_mount_nfs4");
    assert_script_run("chmod 777 $nfs_mount_nfs4");

    assert_script_run("mkdir -p $nfs_mount_nfs3_async");
    assert_script_run("chmod 777 $nfs_mount_nfs3_async");
    assert_script_run("mkdir -p $nfs_mount_nfs4_async");
    assert_script_run("chmod 777 $nfs_mount_nfs4_async");

    assert_script_run("echo $nfs_mount_nfs3 client-node00\\($nfs_permissions\\) >> /etc/exports");
    assert_script_run("echo $nfs_mount_nfs4 client-node00\\($nfs_permissions\\) >> /etc/exports");
    assert_script_run("echo $nfs_mount_nfs3_async client-node00\\($nfs_permissions_async\\) >> /etc/exports");
    assert_script_run("echo $nfs_mount_nfs4_async client-node00\\($nfs_permissions_async\\) >> /etc/exports");

    record_info("EXPORTS", script_output("cat /etc/exports"));

    systemctl("enable nfs-server");
    systemctl("start nfs-server");
    systemctl("is-active nfs-server");

    record_info("NFS config", script_output("cat /etc/sysconfig/nfs"));

    record_info("NFS stat for server", script_output("nfsstat -s"));

    barrier_wait("NFS_SERVER_ENABLED");
    barrier_wait("NFS_CLIENT_ENABLED");
    barrier_wait("NFS_SERVER_CHECK");

    assert_script_run("cd $nfs_mount_nfs3");
    assert_script_run("md5sum -c md5sum.txt");
    record_info("NFS3 checksum", script_output("md5sum -c md5sum.txt"));

    assert_script_run("cd $nfs_mount_nfs4");
    assert_script_run("md5sum -c md5sum.txt");
    record_info("NFS4 checksum", script_output("md5sum -c md5sum.txt"));

    assert_script_run("cd $nfs_mount_nfs3_async");
    assert_script_run("md5sum -c md5sum.txt");
    record_info("NFS3 async checksum", script_output("md5sum -c md5sum.txt"));

    assert_script_run("cd $nfs_mount_nfs4_async");
    assert_script_run("md5sum -c md5sum.txt");
    record_info("NFS4 async checksum", script_output("md5sum -c md5sum.txt"));

    record_info("NFS stat for server", script_output("nfsstat -s"));
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook {
    my ($self) = @_;
    $self->destroy_test_barriers();
    select_serial_terminal;
    export_logs_basic;
}

1;
