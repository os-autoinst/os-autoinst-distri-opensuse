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

    # Compare hashes directly in memory (no temporary new_md5sum.txt file on disk)
    my ($expected_md5) = split(/\s+/, script_output("md5sum testfile"));
    my ($actual_md5) = split(/\s+/, script_output("md5sum $file"));

    record_info("MD5 Check", "$file: $actual_md5 (expected $expected_md5)");
    die "Checksum mismatch for $file! Expected: $expected_md5, Got: $actual_md5"
      unless ($expected_md5 && $actual_md5 && $expected_md5 eq $actual_md5);
}

sub run {
    my ($self) = @_;
    select_serial_terminal();
    record_info("hostname", script_output("hostname"));

    my $client = get_var('CLIENT_NODE', 'client-node00');
    my $nfsd_versions = get_var_array('NFSD_VERSIONS', '3,4');
    my $nfs_options = get_var('NFS_OPTIONS', 'rw,sync,no_root_squash');
    my $nfs_options_async = get_var('NFS_OPTIONS_ASYNC', 'rw,async,no_root_squash');

    my @file_flags = qw(testfile_oflag_direct testfile_oflag_dsync testfile_oflag_sync);

    my %exports = (
        3 => {
            sync => get_var('NFS_MOUNT_NFS3', '/var/lib/nfs-tests/shared_nfs3'),
            async => get_var('NFS_MOUNT_NFS3_ASYNC', '/var/lib/nfs-tests/shared_nfs3_async'),
        },
        4 => {
            sync => get_var('NFS_MOUNT_NFS4', '/var/lib/nfs-tests/shared_nfs4'),
            async => get_var('NFS_MOUNT_NFS4_ASYNC', '/var/lib/nfs-tests/shared_nfs4_async'),
        },
    );

    install_package('nfs-kernel-server', trup_apply => 1);

    for my $version (@$nfsd_versions) {
        die "NFSv$version server support missing in this kernel"
          unless check_nfs_support($version, nfsd => 1);

        record_info('INFO', "Kernel has support for NFSDv$version");

        my $cfg = $exports{$version} or die "No export mapping defined for NFSv$version";
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
            record_info("TESTS", "Checking NFSv$version ($type) at $export_dir");

            assert_script_run("cd $export_dir");

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
