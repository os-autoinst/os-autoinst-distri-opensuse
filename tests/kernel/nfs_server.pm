# SUSE's openQA tests
#
# Copyright 2023-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Provision NFS server, export NFS shares and verify data integrity.
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

    assert_script_run("md5sum $file > new_md5sum.txt");
    record_info("$file: checksum", script_output("cat new_md5sum.txt"));

    my $md5 = script_output("cut -d ' ' -f1 md5sum.txt");
    my $new_md5 = script_output("cut -d ' ' -f1 new_md5sum.txt");

    record_info("Checksums md5 $md5 newMd5: $new_md5");

    die "checksums differ $md5 : $new_md5" unless ($md5 eq $new_md5);
}

sub run {
    my $self = @_;
    my $client = get_var('CLIENT_NODE', 'client-node00');

    select_serial_terminal();
    record_info("hostname", script_output("hostname"));

    my @nfs_versions = get_nfs_versions();

    my $nfs_options = get_var('NFS_OPTIONS', 'rw,sync,no_root_squash');
    my $nfs_options_async = get_var('NFS_OPTIONS_ASYNC', 'rw,async,no_root_squash');

    # following files are copied on the client side using dd with specific flags: direct, dsync, sync
    my $file_flag_direct = 'testfile_oflag_direct';
    my $file_flag_dsync = 'testfile_oflag_dsync';
    my $file_flag_sync = 'testfile_oflag_sync';

    # provision NFS server(s) of various types
    install_package('nfs-kernel-server', trup_apply => 1);

    # configure our exports
    for my $version (@nfs_versions) {
        my $cfg = nfs_mount_config($version);

        record_info('INFO', "Exporting NFSv$version shares");
        create_export($cfg->{remote}, $client, $nfs_options);
        create_export($cfg->{remote_async}, $client, $nfs_options_async);
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

    for my $version (@nfs_versions) {
        my $cfg = nfs_mount_config($version);

        record_info("TESTS: NFSv$version", "Verifying checksums for NFSv$version exports");

        for my $export ($cfg->{remote}, $cfg->{remote_async}) {
            record_info("NFSv$version list all files", script_output("ls $export"));

            assert_script_run("cd $export");
            assert_script_run("md5sum -c md5sum.txt");
            record_info("NFSv$version checksum", script_output("md5sum -c md5sum.txt"));
            record_info("NFSv$version checksum", script_output("cat md5sum.txt"));

            #check files copied with various flags: direct, dsync, sync
            compare_checksums($file_flag_direct);
            compare_checksums($file_flag_dsync);
            compare_checksums($file_flag_sync);
        }
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

Installs C<nfs-kernel-server> and creates a sync and an async export under
C</var/lib/nfs-tests/> for every NFS version returned by
L<Kernel::nfs/get_nfs_versions>.

After the client has written a test file and dd-copies using C<direct>,
C<dsync>, and C<sync> flags, the server verifies data integrity for every
file using md5 checksums.

=head1 Configuration

=head2 CLIENT_NODE

Hostname or IP of the NFS client used in the export access list.
Defaults to C<client-node00>.

=head2 NFS_VERSIONS

Comma-separated list of NFS versions to test, e.g. C<3,4.2>. Overrides the
default version support matrix. See L<Kernel::nfs/get_nfs_versions>.

=head2 NFS_VERSIONS_SKIP

Comma-separated list of NFS versions to leave out of the default support
matrix, e.g. C<4.2>. Ignored if C<NFS_VERSIONS> is set.

=head2 NFS_MOUNT_NFS<VERSION>

Server-side path for the synchronous export of a given NFS version, e.g.
C<NFS_MOUNT_NFS3> or C<NFS_MOUNT_NFS4_2>.
Defaults to C</var/lib/nfs-tests/shared_nfs<version>>.

=head2 NFS_MOUNT_NFS<VERSION>_ASYNC

Server-side path for the asynchronous export of a given NFS version.
Defaults to C</var/lib/nfs-tests/shared_nfs<version>_async>.

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
