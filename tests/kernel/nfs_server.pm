# SUSE's openQA tests
#
# Copyright 2023-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Provision NFS server, export NFSv3/NFSv4 shares and verify data integrity.
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal "select_serial_terminal";
use lockapi;
use utils;
use Utils::Logging "export_logs_basic";
use package_utils 'install_package';
use Kernel::nfs;

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

    my $nfs_mount_nfs3 = get_var('NFS_MOUNT_NFS3', '/var/lib/nfs-tests/shared_nfs3');
    my $nfs_mount_nfs3_async = get_var('NFS_MOUNT_NFS3_ASYNC', '/var/lib/nfs-tests/shared_nfs3_async');
    my $nfs_mount_nfs4 = get_var('NFS_MOUNT_NFS4', '/var/lib/nfs-tests/shared_nfs4');
    my $nfs_mount_nfs4_async = get_var('NFS_MOUNT_NFS4_ASYNC', '/var/lib/nfs-tests/shared_nfs4_async');

    my $nfs_options = get_var('NFS_PERMISSIONS', 'rw,sync,no_root_squash');
    my $nfs_options_async = get_var('NFS_PERMISSIONS_ASYNC', 'rw,async,no_root_squash');

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
    install_package('nfs-kernel-server', trup_apply => 1);

    # configure our exports
    if ($kernel_nfs3 == 1) {
        record_info('INFO', 'Kernel has support for NFSv3');
        create_export($nfs_mount_nfs3, $client, $nfs_options);
        create_export($nfs_mount_nfs3_async, $client, $nfs_options_async);
    } else {
        record_info('INFO', 'Kernel has no support for NFSv3, skipping NFSv3 tests');
    }
    if ($kernel_nfs4 == 1) {
        record_info('INFO', 'Kernel has support for NFSv4');
        create_export($nfs_mount_nfs4, $client, $nfs_options);
        create_export($nfs_mount_nfs4_async, $client, $nfs_options_async);
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

=head1 Description

Provisions the NFS server node of the coordinated multi-machine NFS test.
This module is designed to execute in lockstep with L<tests/kernel/nfs_client.pm>,
synchronised at runtime via shared barriers.

Verifies data integrity on all exports after the client has finished writing.

Installs C<nfs-kernel-server> and creates up to four exports under
C</var/lib/nfs-tests/>, conditional on kernel NFS support detected via
C</proc/config.gz>: NFSv3 sync, NFSv3 async, NFSv4 sync, and NFSv4 async.

After the client has written a test file and dd-copies using C<direct>,
C<dsync>, and C<sync> flags, the server verifies data integrity for every
file using md5 checksums.

=head1 Configuration

=head2 CLIENT_NODE

Hostname or IP of the NFS client used in the export access list.
Defaults to C<client-node00>.

=head2 NFS_MOUNT_NFS3

Server-side path for the NFSv3 synchronous export.
Defaults to C</var/lib/nfs-tests/shared_nfs3>.

=head2 NFS_MOUNT_NFS3_ASYNC

Server-side path for the NFSv3 asynchronous export.
Defaults to C</var/lib/nfs-tests/shared_nfs3_async>.

=head2 NFS_MOUNT_NFS4

Server-side path for the NFSv4 synchronous export.
Defaults to C</var/lib/nfs-tests/shared_nfs4>.

=head2 NFS_MOUNT_NFS4_ASYNC

Server-side path for the NFSv4 asynchronous export.
Defaults to C</var/lib/nfs-tests/shared_nfs4_async>.

=head2 NFS_OPTIONS

Export options applied to synchronous exports.
Defaults to C<rw,sync,no_root_squash>.

=head2 NFS_OPTIONS_ASYNC

Export options applied to asynchronous exports.
Defaults to C<rw,async,no_root_squash>.

=head1 Barriers

=head2 NFS_SERVER_ENABLED

Signals that the NFS server is up and all exports are active.

=head2 NFS_CLIENT_ENABLED

Waits for the client to finish mounting all exports; test data is written after this point.

=head2 NFS_SERVER_CHECK

Both nodes meet here after all checksum verifications are complete.

=cut
