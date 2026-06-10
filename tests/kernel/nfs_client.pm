# SUSE's openQA tests
#
# Copyright 2023-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Provision NFS client, mount NFSv3/NFSv4 shares and write test data.
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal "select_serial_terminal";
use lockapi;
use utils;
use package_utils 'install_package';

sub copy_file {
    my ($flag, $nfs_mount, $file) = @_;
    assert_script_run("dd oflag=$flag if=testfile of=$nfs_mount/$file bs=1024 count=10240");
}

sub run {
    select_serial_terminal();
    record_info("hostname", script_output("hostname"));
    my $server_node = get_var('SERVER_NODE', 'server-node00');

    install_package('nfs-client', trup_apply => 1);

    my $nfs_mount_nfs3 = get_var('NFS_MOUNT_NFS3', '/var/lib/nfs-tests/shared_nfs3');
    my $nfs_mount_nfs3_async = get_var('NFS_MOUNT_NFS3_ASYNC', '/var/lib/nfs-tests/shared_nfs3_async');
    my $nfs_mount_nfs4 = get_var('NFS_MOUNT_NFS4', '/var/lib/nfs-tests/shared_nfs4');
    my $nfs_mount_nfs4_async = get_var('NFS_MOUNT_NFS4_ASYNC', '/var/lib/nfs-tests/shared_nfs4_async');
    my $local_nfs3 = get_var('NFS_LOCAL_NFS3', '/var/lib/nfs-tests/localNFS3');
    my $local_nfs3_async = get_var('NFS_LOCAL_NFS3_ASYNC', '/var/lib/nfs-tests/localNFS3async');
    my $local_nfs4 = get_var('NFS_LOCAL_NFS4', '/var/lib/nfs-tests/localNFS4');
    my $local_nfs4_async = get_var('NFS_LOCAL_NFS4_ASYNC', '/var/lib/nfs-tests/localNFS4async');
    my $multipath = get_var('NFS_MULTIPATH', '0');

    # check kernel config options and set the variables
    my $kernel_nfs3 = 0;
    my $kernel_nfs4 = 0;
    my $kernel_nfs4_1 = 0;
    my $kernel_nfs4_2 = 0;
    my $kernel_nfsd_v3 = 0;
    my $kernel_nfsd_v4 = 0;

    $kernel_nfs3 = 1 unless script_run('zgrep "CONFIG_NFS_V3=[my]" /proc/config.gz');
    $kernel_nfs4 = 1 unless script_run('zgrep "CONFIG_NFS_V4=[my]" /proc/config.gz');
    $kernel_nfs4_1 = 1 unless script_run('zgrep "CONFIG_NFS_V4_1=[my]" /proc/config.gz');
    $kernel_nfs4_2 = 1 unless script_run('zgrep "CONFIG_NFS_V4_2=[my]" /proc/config.gz');
    $kernel_nfsd_v3 = 1 unless script_run('zgrep "CONFIG_NFSD=[my]" /proc/config.gz');
    $kernel_nfsd_v4 = 1 unless script_run('zgrep "CONFIG_NFSD_V4=[my]" /proc/config.gz');

    barrier_wait("NFS_SERVER_ENABLED");
    record_info("showmount", script_output("showmount -e $server_node"));

    if ($kernel_nfs3 == 1) {
        record_info('INFO', 'Kernel has support for NFSv3');
        assert_script_run("mkdir -p $local_nfs3 $local_nfs3_async");
        assert_script_run("mount -t nfs -o nfsvers=3,sync $server_node:$nfs_mount_nfs3 $local_nfs3");
        assert_script_run("mount -t nfs -o nfsvers=3 $server_node:$nfs_mount_nfs3_async $local_nfs3_async");
    } else {
        record_info('INFO', 'Kernel has no support for NFSv3, skipping NFSv3 tests');
    }

    if ($kernel_nfs4 == 1) {
        record_info('INFO', 'Kernel has support for NFSv4');
        assert_script_run("mkdir -p $local_nfs4 $local_nfs4_async");
        assert_script_run("mount -t nfs -o nfsvers=4,sync $server_node:$nfs_mount_nfs4 $local_nfs4");
        assert_script_run("mount -t nfs -o nfsvers=4 $server_node:$nfs_mount_nfs4_async $local_nfs4_async");
    } else {
        record_info('INFO', 'Kernel has no support for NFSv4, skipping NFSv4tests');
    }

    barrier_wait("NFS_CLIENT_ENABLED");

    #run basic checks - add a file to each folder and check for the checksum
    #proper tests should come in the next modules
    assert_script_run("dd if=/dev/zero of=testfile bs=1024 count=10240");
    assert_script_run("md5sum testfile > md5sum.txt");

    if ($kernel_nfs3 == 1) {
        assert_script_run("cp testfile md5sum.txt $local_nfs3");
        assert_script_run("cp testfile md5sum.txt $local_nfs3_async");

        copy_file('direct', $local_nfs3, 'testfile_oflag_direct');
        copy_file('dsync', $local_nfs3, 'testfile_oflag_dsync');
        copy_file('sync', $local_nfs3, 'testfile_oflag_sync');

        copy_file('direct', $local_nfs3_async, 'testfile_oflag_direct');
        copy_file('dsync', $local_nfs3_async, 'testfile_oflag_dsync');
        copy_file('sync', $local_nfs3_async, 'testfile_oflag_sync');
    }
    if ($kernel_nfs4 == 1) {
        assert_script_run("cp testfile md5sum.txt $local_nfs4");
        assert_script_run("cp testfile md5sum.txt $local_nfs4_async");

        copy_file('direct', $local_nfs4, 'testfile_oflag_direct');
        copy_file('dsync', $local_nfs4, 'testfile_oflag_dsync');
        copy_file('sync', $local_nfs4, 'testfile_oflag_sync');

        copy_file('direct', $local_nfs4_async, 'testfile_oflag_direct');
        copy_file('dsync', $local_nfs4_async, 'testfile_oflag_dsync');
        copy_file('sync', $local_nfs4_async, 'testfile_oflag_sync');
    }

    barrier_wait("NFS_SERVER_CHECK");
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook {
    my ($self) = @_;
    $self->destroy_test_barriers();
    select_serial_terminal;
}

1;

=head1 Description

Provisions the NFS client node of the coordinated multi-machine NFS test.
This module is designed to execute in lockstep with L<tests/kernel/nfs_server.pm>,
synchronised at runtime via shared barriers.

Installs C<nfs-client>, mounts the exports provided by the server (NFSv3 and
NFSv4, sync and async variants, subject to kernel support), creates a 10 MiB
test file with C<dd>, computes its md5 checksum, then copies it to every mount
using C<cp> and C<dd> with C<direct>, C<dsync>, and C<sync> flags.

=head1 Configuration

=head2 SERVER_NODE

Hostname or IP of the NFS server.
Defaults to C<server-node00>.

=head2 NFS_MOUNT_NFS3

Server-side export path for the NFSv3 synchronous mount.
Defaults to C</var/lib/nfs-tests/shared_nfs3>.

=head2 NFS_MOUNT_NFS3_ASYNC

Server-side export path for the NFSv3 asynchronous mount.
Defaults to C</var/lib/nfs-tests/shared_nfs3_async>.

=head2 NFS_MOUNT_NFS4

Server-side export path for the NFSv4 synchronous mount.
Defaults to C</var/lib/nfs-tests/shared_nfs4>.

=head2 NFS_MOUNT_NFS4_ASYNC

Server-side export path for the NFSv4 asynchronous mount.
Defaults to C</var/lib/nfs-tests/shared_nfs4_async>.

=head2 NFS_LOCAL_NFS3

Local mountpoint for the NFSv3 synchronous export.
Defaults to C</var/lib/nfs-tests/localNFS3>.

=head2 NFS_LOCAL_NFS3_ASYNC

Local mountpoint for the NFSv3 asynchronous export.
Defaults to C</var/lib/nfs-tests/localNFS3async>.

=head2 NFS_LOCAL_NFS4

Local mountpoint for the NFSv4 synchronous export.
Defaults to C</var/lib/nfs-tests/localNFS4>.

=head2 NFS_LOCAL_NFS4_ASYNC

Local mountpoint for the NFSv4 asynchronous export.
Defaults to C</var/lib/nfs-tests/localNFS4async>.

=head2 NFS_MULTIPATH

When set to C<1>, enables multipath for NFS mounts.
Defaults to C<0>.

=head1 Barriers

=head2 NFS_SERVER_ENABLED

Waits for the server to be ready before mounting the exports.

=head2 NFS_CLIENT_ENABLED

Signals that all NFS exports are mounted; test data is written after this point.

=head2 NFS_SERVER_CHECK

Signals that the client has finished writing test data; the server proceeds to verify checksums after this point.

=cut
