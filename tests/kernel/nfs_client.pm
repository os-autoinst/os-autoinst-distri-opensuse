# SUSE's openQA tests
#
# Copyright 2023-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Provision NFS client, mount NFS shares and write test data.
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

    my @nfs_versions = get_nfs_versions();
    my $multipath = get_var('NFS_MULTIPATH', '0');

    barrier_wait("NFS_SERVER_ENABLED");
    record_info("showmount", script_output("showmount -e $server_node"));

    for my $version (@nfs_versions) {
        my $cfg = nfs_mount_config($version);

        record_info('INFO', "Mounting NFSv$version exports");
        assert_script_run("mkdir -p $cfg->{local} $cfg->{local_async}");
        assert_script_run("mount -t nfs -o nfsvers=$version,sync $server_node:$cfg->{remote} $cfg->{local}");
        assert_script_run("mount -t nfs -o nfsvers=$version $server_node:$cfg->{remote_async} $cfg->{local_async}");
    }

    barrier_wait("NFS_CLIENT_ENABLED");

    #run basic checks - add a file to each folder and check for the checksum
    #proper tests should come in the next modules
    assert_script_run("dd if=/dev/zero of=testfile bs=1024 count=10240");
    assert_script_run("md5sum testfile > md5sum.txt");

    for my $version (@nfs_versions) {
        my $cfg = nfs_mount_config($version);

        for my $mount ($cfg->{local}, $cfg->{local_async}) {
            assert_script_run("cp testfile md5sum.txt $mount");

            copy_file('direct', $mount, 'testfile_oflag_direct');
            copy_file('dsync', $mount, 'testfile_oflag_dsync');
            copy_file('sync', $mount, 'testfile_oflag_sync');
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

Installs C<nfs-client>, mounts the exports provided by the server (sync and
async variants for every NFS version returned by
L<Kernel::nfs/get_nfs_versions>), creates a 10 MiB test file with C<dd>,
computes its md5 checksum, then copies it to every mount using C<cp> and
C<dd> with C<direct>, C<dsync>, and C<sync> flags.

=head1 Configuration

=head2 SERVER_NODE

Hostname or IP of the NFS server.
Defaults to C<server-node00>.

=head2 NFS_VERSIONS

Comma-separated list of NFS versions to test, e.g. C<3,4.2>. Overrides the
default version support matrix. See L<Kernel::nfs/get_nfs_versions>.

=head2 NFS_VERSIONS_SKIP

Comma-separated list of NFS versions to leave out of the default support
matrix, e.g. C<4.2>. Ignored if C<NFS_VERSIONS> is set.

=head2 NFS_MOUNT_NFS<VERSION>

Server-side export path for a given NFS version, e.g. C<NFS_MOUNT_NFS3> or
C<NFS_MOUNT_NFS4_2>.
Defaults to C</var/lib/nfs-tests/shared_nfs<version>>.

=head2 NFS_MOUNT_NFS<VERSION>_ASYNC

Server-side export path for the asynchronous mount of a given NFS version.
Defaults to C</var/lib/nfs-tests/shared_nfs<version>_async>.

=head2 NFS_LOCAL_NFS<VERSION>

Local mountpoint for a given NFS version.
Defaults to C</var/lib/nfs-tests/localNFS<version>>.

=head2 NFS_LOCAL_NFS<VERSION>_ASYNC

Local mountpoint for the asynchronous mount of a given NFS version.
Defaults to C</var/lib/nfs-tests/localNFS<version>async>.

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
