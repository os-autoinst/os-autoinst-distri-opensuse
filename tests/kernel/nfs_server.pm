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

sub compare_checksums {
    my ($file) = @_;

    my ($expected_md5) = split(/\s+/, script_output("cat md5sum.txt"));
    my ($actual_md5) = split(/\s+/, script_output("md5sum $file"));

    record_info("$file: checksum", "expected $expected_md5, got $actual_md5");

    die "checksums differ $expected_md5 : $actual_md5" unless ($actual_md5 eq $expected_md5);
}

sub run {
    my ($self) = @_;
    select_serial_terminal();
    record_info("hostname", script_output("hostname"));

    my $client = get_var('CLIENT_NODE', 'client-node00');
    my $nfsd_versions = get_var_array('NFSD_VERSIONS', '3,4.0,4.1,4.2');
    my $nfs_options = get_var('NFS_OPTIONS', 'rw,sync,no_root_squash');
    my $nfs_options_async = get_var('NFS_OPTIONS_ASYNC', 'rw,async,no_root_squash');

    my @file_flags = qw(testfile_oflag_direct testfile_oflag_dsync testfile_oflag_sync);

    # Every NFS version gets its own export directory, so that concurrent
    # writes from different minor-version mounts on the client never collide.
    my %exports;
    for my $version (@$nfsd_versions) {
        (my $suffix = $version) =~ s/\./_/g;
        $exports{$version} = {
            sync => get_var("NFS_MOUNT_NFS$suffix", "/var/lib/nfs-tests/shared_nfs$suffix"),
            async => get_var("NFS_MOUNT_NFS${suffix}_ASYNC", "/var/lib/nfs-tests/shared_nfs${suffix}_async"),
        };
    }

    install_package('nfs-kernel-server', trup_apply => 1);

    for my $version (@$nfsd_versions) {
        record_info('INFO', "Exporting NFSv$version");

        my $cfg = $exports{$version};
        create_export($cfg->{sync}, $client, $nfs_options);
        create_export($cfg->{async}, $client, $nfs_options_async);
    }

    systemctl("enable --now rpcbind nfs-server");
    systemctl("restart nfs-server");
    systemctl("is-active rpcbind nfs-server");

    record_info("RPC", script_output("rpcinfo"));
    record_info("NFS stat", script_output("nfsstat -s"));

    barrier_wait("NFS_SERVER_ENABLED");
    barrier_wait("NFS_CLIENT_ENABLED");
    # client writes testfile and all oflag copies between NFS_CLIENT_ENABLED
    # and NFS_SERVER_CHECK; verification must not start before this barrier
    barrier_wait("NFS_SERVER_CHECK");

    for my $version (@$nfsd_versions) {
        my $cfg = $exports{$version};

        for my $type (qw(sync async)) {
            my $export_dir = $cfg->{$type};
            assert_script_run("cd $export_dir");

            # NFSD_VERSIONS and NFS_VERSIONS may legitimately be configured
            # to differ (e.g. testing a narrower client-side list), leaving
            # some server-side exports without client-written test data.
            if (script_run("test -e md5sum.txt") != 0) {
                record_info("SKIP", "NFSv$version ($type) at $export_dir: no test data, client did not mount this version", result => 'softfail');
                next;
            }

            record_info("TESTS", "Checking NFSv$version ($type) at $export_dir");
            compare_checksums('testfile');
            compare_checksums($_) for @file_flags;
        }
    }
    record_info("NFS stat final", script_output("nfsstat -s"));
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook {
    my ($self) = @_;
    $self->destroy_test_barriers();
    select_serial_terminal;
    export_logs_basic;
    dump_nfs_kconfig();
}

1;

=head1 Description

Provisions the NFS server node of the coordinated multi-machine NFS test.
This module is designed to execute in lockstep with L<tests/kernel/nfs_client.pm>,
synchronised at runtime via shared barriers.

Verifies data integrity on all exports after the client has finished writing.

Installs C<nfs-kernel-server> and creates a sync and an async export under
C</var/lib/nfs-tests/> for every version in NFSD_VERSIONS. No kernel-support
pre-check is done: C<exportfs> entries don't negotiate a protocol version,
so any real incompatibility surfaces when the client attempts to mount.
Every version gets its own export directory, so that concurrent writes
from different NFSv4 minor-version mounts on the client never collide.

After the client has written a test file and dd-copies using C<direct>,
C<dsync>, and C<sync> flags, the server verifies data integrity for every
file using md5 checksums.

=head1 Configuration

=head2 CLIENT_NODE

Hostname or IP of the NFS client used in the export access list.
Defaults to C<client-node00>.

=head2 NFSD_VERSIONS

NFS versions to export and verify.
Defaults to C<3,4.0,4.1,4.2>. Pass a narrower list here to exclude
versions the client is known not to support (must match what NFS_VERSIONS
requests on the client side, since each version needs a matching export).

=head2 NFS_MOUNT_NFS3, NFS_MOUNT_NFS4_0, NFS_MOUNT_NFS4_1, NFS_MOUNT_NFS4_2

Server-side path for the synchronous export of the matching version (C<.> in
the version replaced by C<_>, e.g. NFSv4.1 uses C<NFS_MOUNT_NFS4_1>).
Defaults to C</var/lib/nfs-tests/shared_nfsVERSION>.

=head2 NFS_MOUNT_NFS3_ASYNC, NFS_MOUNT_NFS4_0_ASYNC, NFS_MOUNT_NFS4_1_ASYNC, NFS_MOUNT_NFS4_2_ASYNC

Server-side path for the asynchronous export of the matching version.
Defaults to C</var/lib/nfs-tests/shared_nfsVERSION_async>.

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
