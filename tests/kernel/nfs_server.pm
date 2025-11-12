# SUSE's openQA tests
#
# Copyright 2023-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: NFS server
#    This module provisions the NFS server and then runs some basic sanity tests
#    NFS server - provisioned on SUSE/openSUSE - provides specific exports:
#      - NFS v3 with sync and async flags
#      - NFS v4 with sync and async flags
#    NFS client (tests/kernel/nfs_client.pm) creates a file using dd tool and then copies
#    that file to all exports mounted on the client side.
#    Data integrity of the file is checked with the md5 checksum
#
#    Extension to the NFS tests uses dd tool for copying created file using various flags,
#    specifically:
#      - direct
#      - dsync
#      - sync
#    An earlier created file is copied with each flag to each mounted export and then md5 checksum is
#    used again to check data integridty for each file copied with dd tool with all each flag

# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base "opensusebasetest";
use testapi;
use serial_terminal "select_serial_terminal";
use lockapi;
use utils;
use Utils::Logging "export_logs_basic";

# create a mountpoint and the corresponding export with
# specified permissions
sub create_mount_and_export {
    my ($mountpoint, $cl, $permissions) = @_;

    assert_script_run "mkdir -p $mountpoint";
    assert_script_run "chmod 777 $mountpoint";
    assert_script_run "echo $mountpoint $cl\\($permissions\\) >> /etc/exports";
}

sub compare_checksums {
    my ($file) = @_;

    assert_script_run("md5sum $file > new_md5sum.txt");
    record_info("$file: checksum", script_output("cat new_md5sum.txt"));

    my $md5 = script_output("cut -d ' ' -f1 md5sum.txt");
    my $new_md5 = script_output("cut -d ' ' -f1 new_md5sum.txt");

    record_info("Checksums md5 $md5 newMd5: $new_md5");

    die "checksums differ $md5 : $new_md5" unless ($md5 eq $new_md5);
}

sub run {
    my $self = @_;
    my $kernel_nfs3 = 0;
    my $kernel_nfs4 = 0;
    my $kernel_nfs4_1 = 0;
    my $kernel_nfs4_2 = 0;
    my $kernel_nfsd_v3 = 0;
    my $kernel_nfsd_v4 = 0;
    my $client = get_var('CLIENT_NODE', 'client-node00');

    select_serial_terminal();
    record_info("hostname", script_output("hostname"));

    my $nfs_mount_nfs3 = get_var('NFS_MOUNT_NFS3', '/nfs/shared_nfs3');
    my $nfs_mount_nfs3_async = get_var('NFS_MOUNT_NFS3_ASYNC', '/nfs/shared_nfs3_async');
    my $nfs_mount_nfs4 = get_var('NFS_MOUNT_NFS4', '/nfs/shared_nfs4');
    my $nfs_mount_nfs4_async = get_var('NFS_MOUNT_NFS4_ASYNC', '/nfs/shared_nfs4_async');

    my $nfs_permissions = get_var('NFS_PERMISSIONS', 'rw,sync,no_root_squash');
    my $nfs_permissions_async = get_var('NFS_PERMISSIONS_ASYNC', 'rw,async,no_root_squash');

    # check kernel config options and set the variables
    $kernel_nfs3 = 1 unless script_run('zgrep "CONFIG_NFS_V3=[my]" /proc/config.gz');
    $kernel_nfs4 = 1 unless script_run('zgrep "CONFIG_NFS_V4=[my]" /proc/config.gz');
    $kernel_nfs4_1 = 1 unless script_run('zgrep "CONFIG_NFS_V4_1=[my]" /proc/config.gz');
    $kernel_nfs4_2 = 1 unless script_run('zgrep "CONFIG_NFS_V4_2=[my]" /proc/config.gz');
    $kernel_nfsd_v3 = 1 unless script_run('zgrep "CONFIG_NFSD=[my]" /proc/config.gz');
    $kernel_nfsd_v4 = 1 unless script_run('zgrep "CONFIG_NFSD_V4=[my]" /proc/config.gz');

    # following files are copied on the client side using dd with specific flags: direct, dsync, sync
    my $file_flag_direct = 'testfile_oflag_direct';
    my $file_flag_dsync = 'testfile_oflag_dsync';
    my $file_flag_sync = 'testfile_oflag_sync';

    # provision NFS server(s) of various types
    zypper_call("in nfs-kernel-server");

    # configure our exports
    if ($kernel_nfs3 == 1) {
        record_info('INFO', 'Kernel has support for NFSv3');
        create_mount_and_export($nfs_mount_nfs3, $client, $nfs_permissions);
        create_mount_and_export($nfs_mount_nfs3_async, $client, $nfs_permissions_async);
    } else {
        record_info('INFO', 'Kernel has no support for NFSv3, skipping NFSv3 tests');
    }
    if ($kernel_nfs4 == 1) {
        record_info('INFO', 'Kernel has support for NFSv4');
        create_mount_and_export($nfs_mount_nfs4, $client, $nfs_permissions);
        create_mount_and_export($nfs_mount_nfs4_async, $client, $nfs_permissions_async);
    } else {
        record_info('INFO', 'Kernel has no support for NFSv4, skipping NFSv4 tests');
    }

    record_info("EXPORTS", script_output("cat /etc/exports"));

    systemctl("enable rpcbind --now");
    systemctl("is-active rpcbind");
    systemctl("enable nfs-server --now");
    systemctl("restart nfs-server");
    systemctl("is-active nfs-server");

    record_info("RPC", script_output("rpcinfo"));
    record_info("NFS config", script_output("cat /etc/sysconfig/nfs"));

    #my $nfsstat = script_output("nfsstat -s");
    record_info("NFS stat for server", script_output("nfsstat -s"));

    barrier_wait("NFS_SERVER_ENABLED");
    barrier_wait("NFS_CLIENT_ENABLED");
    barrier_wait("NFS_SERVER_CHECK");

    if ($kernel_nfs3 == 1) {
        #checking files in /nfs/shared_nfs3
        record_info("TESTS: NFS3");
        record_info("NFS3 list all files", script_output("ls $nfs_mount_nfs3"));

        assert_script_run("cd $nfs_mount_nfs3");

        assert_script_run("md5sum -c md5sum.txt");
        record_info("NFS3 checksum", script_output("md5sum -c md5sum.txt"));
        record_info("NFS3 checksum", script_output("cat md5sum.txt"));

        #check files copied with various flags: direct, dsync, sync
        compare_checksums($file_flag_direct);
        compare_checksums($file_flag_dsync);
        compare_checksums($file_flag_sync);

        #checking files in /nfs/shared_nfs3_async
        record_info("TESTS: NFS3 async");

        assert_script_run("cd $nfs_mount_nfs3_async");
        assert_script_run("md5sum -c md5sum.txt");
        record_info("NFS3 async checksum", script_output("md5sum -c md5sum.txt"));

        #check files copied with various flags: direct, dsync, sync
        compare_checksums($file_flag_direct);
        compare_checksums($file_flag_dsync);
        compare_checksums($file_flag_sync);
    }

    if ($kernel_nfs4 == 1) {
        #checking files in /nfs/shared_nfs4
        record_info("TESTS: NFS4");

        assert_script_run("cd $nfs_mount_nfs4");
        assert_script_run("md5sum -c md5sum.txt");
        record_info("NFS4 checksum", script_output("md5sum -c md5sum.txt"));

        #check files copied with various flags: direct, dsync, sync
        compare_checksums($file_flag_direct);
        compare_checksums($file_flag_dsync);
        compare_checksums($file_flag_sync);

        #checking files in /nfs/shared_nfs4_async
        record_info("TESTS: NFS4 async");

        assert_script_run("cd $nfs_mount_nfs4_async");
        assert_script_run("md5sum -c md5sum.txt");
        record_info("NFS4 async checksum", script_output("md5sum -c md5sum.txt"));

        #check files copied with various flags: direct, dsync, sync
        compare_checksums($file_flag_direct);
        compare_checksums($file_flag_dsync);
        compare_checksums($file_flag_sync);
    }

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
