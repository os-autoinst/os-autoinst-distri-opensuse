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
use Kernel::nfs;

sub copy_file {
    my ($flag, $nfs_mount, $file) = @_;
    assert_script_run("dd oflag=$flag if=testfile of=$nfs_mount/$file bs=1024 count=10240");
}

sub run {
    select_serial_terminal();
    record_info("hostname", script_output("hostname"));
    my $server_node = get_var('SERVER_NODE', 'server-node00');

    install_package('nfs-client', trup_apply => 1);

    my $nfsd_versions = get_var_array('NFSD_VERSIONS', '3,4');

    my %mount_map = (
        3 => {
            export_sync => get_var('NFS_MOUNT_NFS3', '/var/lib/nfs-tests/shared_nfs3'),
            export_async => get_var('NFS_MOUNT_NFS3_ASYNC', '/var/lib/nfs-tests/shared_nfs3_async'),
            local_sync => get_var('NFS_LOCAL_NFS3', '/var/lib/nfs-tests/localNFS3'),
            local_async => get_var('NFS_LOCAL_NFS3_ASYNC', '/var/lib/nfs-tests/localNFS3async'),
        },
        4 => {
            export_sync => get_var('NFS_MOUNT_NFS4', '/var/lib/nfs-tests/shared_nfs4'),
            export_async => get_var('NFS_MOUNT_NFS4_ASYNC', '/var/lib/nfs-tests/shared_nfs4_async'),
            local_sync => get_var('NFS_LOCAL_NFS4', '/var/lib/nfs-tests/localNFS4'),
            local_async => get_var('NFS_LOCAL_NFS4_ASYNC', '/var/lib/nfs-tests/localNFS4async'),
        },
    );

    my @file_flags = qw(direct dsync sync);

    barrier_wait("NFS_SERVER_ENABLED");
    record_info("showmount", script_output("showmount -e $server_node"));

    for my $version (@$nfsd_versions) {
        unless (check_nfs_support($version)) {
            record_info('INFO', "Kernel has no support for NFSv$version, skipping");
            next;
        }

        record_info('INFO', "Kernel has support for NFSv$version");
        my $cfg = $mount_map{$version} or die "No mount mapping defined for NFSv$version";

        assert_script_run("mkdir -p $cfg->{local_sync} $cfg->{local_async}");
        assert_script_run("mount -t nfs -o nfsvers=$version,sync $server_node:$cfg->{export_sync} $cfg->{local_sync}");
        assert_script_run("mount -t nfs -o nfsvers=$version $server_node:$cfg->{export_async} $cfg->{local_async}");
    }

    barrier_wait("NFS_CLIENT_ENABLED");

    assert_script_run("dd if=/dev/zero of=testfile bs=1024 count=10240");
    assert_script_run("md5sum testfile > md5sum.txt");

    for my $version (@$nfsd_versions) {
        next unless check_nfs_support($version);
        my $cfg = $mount_map{$version};

        for my $local_dir ($cfg->{local_sync}, $cfg->{local_async}) {
            assert_script_run("cp testfile md5sum.txt $local_dir");
            copy_file($_, $local_dir, "testfile_oflag_$_") for @file_flags;
        }
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
