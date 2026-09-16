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

    my $nfs_versions = get_var_array('NFS_VERSIONS', '3,4.0,4.1,4.2');

    # Every NFS version gets its own export/mount pair, so that concurrent
    # writes from different NFSv4 minor-version mounts never collide.
    my %mount_map;
    for my $version (@$nfs_versions) {
        (my $suffix = $version) =~ s/\./_/g;
        $mount_map{$version} = {
            export_sync => get_var("NFS_MOUNT_NFS$suffix", "/var/lib/nfs-tests/shared_nfs$suffix"),
            export_async => get_var("NFS_MOUNT_NFS${suffix}_ASYNC", "/var/lib/nfs-tests/shared_nfs${suffix}_async"),
            local_sync => get_var("NFS_LOCAL_NFS$suffix", "/var/lib/nfs-tests/localNFS$suffix"),
            local_async => get_var("NFS_LOCAL_NFS${suffix}_ASYNC", "/var/lib/nfs-tests/localNFS${suffix}_async"),
        };
    }

    my @file_flags = qw(direct dsync sync);

    barrier_wait("NFS_SERVER_ENABLED");
    record_info("showmount", script_output("showmount -e $server_node"));

    for my $version (@$nfs_versions) {
        record_info('INFO', "Mounting NFSv$version");
        my $cfg = $mount_map{$version};

        assert_script_run("mkdir -p $cfg->{local_sync} $cfg->{local_async}");
        assert_script_run("mount -t nfs -o vers=$version,sync $server_node:$cfg->{export_sync} $cfg->{local_sync}");
        assert_script_run("mount -t nfs -o vers=$version $server_node:$cfg->{export_async} $cfg->{local_async}");
    }

    barrier_wait("NFS_CLIENT_ENABLED");

    assert_script_run("dd if=/dev/zero of=testfile bs=1024 count=10240");
    assert_script_run("md5sum testfile > md5sum.txt");

    for my $version (@$nfs_versions) {
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
    dump_nfs_kconfig();
}

1;

=head1 Description

Provisions the NFS client node of the coordinated multi-machine NFS test.
This module is designed to execute in lockstep with L<tests/kernel/nfs_server.pm>,
synchronised at runtime via shared barriers.

Installs C<nfs-client> and mounts the exports provided by the server for
every version in NFS_VERSIONS. No kernel-support pre-check is done: the
mount command itself is the test, and fails the module if the client
kernel or the requested version doesn't work. Creates a 10 MiB test file
with C<dd>, computes its md5 checksum, then copies it to every mount
using C<cp> and C<dd> with C<direct>, C<dsync>, and C<sync> flags. Every
version gets its own export/mount pair, so that concurrent writes from
different NFSv4 minor-version mounts never collide.

=head1 Configuration

=head2 SERVER_NODE

Hostname or IP of the NFS server.
Defaults to C<server-node00>.

=head2 NFS_VERSIONS

NFS versions to mount and verify.
Defaults to C<3,4.0,4.1,4.2>. Pass a narrower list here to exclude
versions known not to work on the product under test (e.g. NFSv4.0 on
current Tumbleweed) - the mount itself fails otherwise.

=head2 NFS_MOUNT_NFS3, NFS_MOUNT_NFS4_0, NFS_MOUNT_NFS4_1, NFS_MOUNT_NFS4_2

Server-side export path for the synchronous mount of the matching version
(C<.> in the version replaced by C<_>, e.g. NFSv4.1 uses C<NFS_MOUNT_NFS4_1>).
Defaults to C</var/lib/nfs-tests/shared_nfsVERSION>.

=head2 NFS_MOUNT_NFS3_ASYNC, NFS_MOUNT_NFS4_0_ASYNC, NFS_MOUNT_NFS4_1_ASYNC, NFS_MOUNT_NFS4_2_ASYNC

Server-side export path for the asynchronous mount of the matching version.
Defaults to C</var/lib/nfs-tests/shared_nfsVERSION_async>.

=head2 NFS_LOCAL_NFS3, NFS_LOCAL_NFS4_0, NFS_LOCAL_NFS4_1, NFS_LOCAL_NFS4_2

Local mountpoint for the synchronous export of the matching version.
Defaults to C</var/lib/nfs-tests/localNFSVERSION>.

=head2 NFS_LOCAL_NFS3_ASYNC, NFS_LOCAL_NFS4_0_ASYNC, NFS_LOCAL_NFS4_1_ASYNC, NFS_LOCAL_NFS4_2_ASYNC

Local mountpoint for the asynchronous export of the matching version.
Defaults to C</var/lib/nfs-tests/localNFSVERSION_async>.

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
