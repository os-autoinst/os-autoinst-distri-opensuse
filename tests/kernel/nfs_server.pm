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

    assert_script_run("md5sum $file > new_md5sum.txt");
    record_info("$file: checksum", script_output("cat new_md5sum.txt"));

    my $md5 = script_output("cut -d ' ' -f1 md5sum.txt");
    my $new_md5 = script_output("cut -d ' ' -f1 new_md5sum.txt");

    record_info("Checksums md5 $md5 newMd5: $new_md5");

    die "checksums differ $md5 : $new_md5" unless ($md5 eq $new_md5);
}

sub verify_test_data {
    my ($dir, @files) = @_;

    assert_script_run("cd $dir");
    record_info("$dir: files", script_output("ls -l"));
    record_info("$dir: checksum", script_output("md5sum -c md5sum.txt"));
    compare_checksums($_) foreach (@files);
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

    my $nfs_krb5 = 0;
    if (get_var('NFS_KRB5')) {
        $nfs_krb5 = kernel_supports_nfs_krb5();
        record_info('INFO', 'Kernel has no CONFIG_RPCSEC_GSS_KRB5, skipping NFS Kerberos tests') unless $nfs_krb5;
    }
    my @krb5_flavors = @{get_var_array('NFS_KRB5_FLAVORS', 'krb5,krb5i,krb5p')};

    my $nfs_mount_nfs3 = get_var('NFS_MOUNT_NFS3', '/var/lib/nfs-tests/shared_nfs3');
    my $nfs_mount_nfs3_async = get_var('NFS_MOUNT_NFS3_ASYNC', '/var/lib/nfs-tests/shared_nfs3_async');
    my $nfs_mount_nfs4 = get_var('NFS_MOUNT_NFS4', '/var/lib/nfs-tests/shared_nfs4');
    my $nfs_mount_nfs4_async = get_var('NFS_MOUNT_NFS4_ASYNC', '/var/lib/nfs-tests/shared_nfs4_async');
    my $nfs_mount_nfs3_krb5 = get_var('NFS_MOUNT_NFS3_KRB5', '/var/lib/nfs-tests/shared_nfs3_krb5');
    my $nfs_mount_nfs3_krb5_async = get_var('NFS_MOUNT_NFS3_KRB5_ASYNC', '/var/lib/nfs-tests/shared_nfs3_krb5_async');
    my $nfs_mount_nfs4_krb5 = get_var('NFS_MOUNT_NFS4_KRB5', '/var/lib/nfs-tests/shared_nfs4_krb5');
    my $nfs_mount_nfs4_krb5_async = get_var('NFS_MOUNT_NFS4_KRB5_ASYNC', '/var/lib/nfs-tests/shared_nfs4_krb5_async');

    my $nfs_options = get_var('NFS_OPTIONS', 'rw,sync,no_root_squash');
    my $nfs_options_async = get_var('NFS_OPTIONS_ASYNC', 'rw,async,no_root_squash');

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

    # Kerberos exports, only for NFS versions the kernel supports
    my @krb5_exports = grep { $nfs_krb5 && $_->{supported} } (
        {version => 3, supported => $kernel_nfs3, sync => $nfs_mount_nfs3_krb5, async => $nfs_mount_nfs3_krb5_async},
        {version => 4, supported => $kernel_nfs4, sync => $nfs_mount_nfs4_krb5, async => $nfs_mount_nfs4_krb5_async},
    );
    if (@krb5_exports) {
        my $sec = 'sec=' . join(':', @krb5_flavors);
        record_info('INFO', 'Testing NFS with Kerberos');
        setup_nfs_krb5_server;
        foreach my $export (@krb5_exports) {
            create_export($export->{sync}, $client, "$nfs_options,$sec");
            create_export($export->{async}, $client, "$nfs_options_async,$sec");
        }
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

    my @files = ($file_flag_direct, $file_flag_dsync, $file_flag_sync);
    if ($kernel_nfs3 == 1) {
        record_info("TESTS: NFS3");
        verify_test_data($nfs_mount_nfs3, @files);
        record_info("TESTS: NFS3 async");
        verify_test_data($nfs_mount_nfs3_async, @files);
    }

    if ($kernel_nfs4 == 1) {
        record_info("TESTS: NFS4");
        verify_test_data($nfs_mount_nfs4, @files);
        record_info("TESTS: NFS4 async");
        verify_test_data($nfs_mount_nfs4_async, @files);
    }

    # The client writes the data of each flavor in its own subdirectory
    foreach my $export (@krb5_exports) {
        foreach my $type (qw(sync async)) {
            foreach my $sec (@krb5_flavors) {
                my $dir = "$export->{$type}/$sec";
                record_info("TESTS: NFS$export->{version} $type $sec");
                die "No test data in $dir: NFS_KRB5 and NFS_KRB5_FLAVORS must be the same on server and client"
                  if script_run("test -d $dir");
                verify_test_data($dir, @files);
            }
        }
    }

    record_info("NFS stat for server", script_output("nfsstat -s"));
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook {
    select_serial_terminal;
    upload_nfs_krb5_logs if get_var('NFS_KRB5');
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

With C<NFS_KRB5>, the server is also the KDC of a test Kerberos realm and
exports one more sync and async share for NFSv3 and NFSv4 that only allow
Kerberos security flavors, subject to kernel support.
The client writes the same test data once for each flavor.

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

=head2 NFS_MOUNT_NFS3_KRB5

Server-side path for the NFSv3 export with Kerberos security flavors.
Defaults to C</var/lib/nfs-tests/shared_nfs3_krb5>.

=head2 NFS_MOUNT_NFS3_KRB5_ASYNC

Server-side path for the asynchronous NFSv3 export with Kerberos security
flavors. Defaults to C</var/lib/nfs-tests/shared_nfs3_krb5_async>.

=head2 NFS_MOUNT_NFS4_KRB5

Server-side path for the NFSv4 export with Kerberos security flavors.
Defaults to C</var/lib/nfs-tests/shared_nfs4_krb5>.

=head2 NFS_MOUNT_NFS4_KRB5_ASYNC

Server-side path for the asynchronous NFSv4 export with Kerberos security
flavors. Defaults to C</var/lib/nfs-tests/shared_nfs4_krb5_async>.

=head2 NFS_KRB5

When set to C<1>, also test NFSv3 and NFSv4 with Kerberos. The kernel must
support C<CONFIG_RPCSEC_GSS_KRB5>, else the Kerberos tests are skipped.
Each NFS version is tested only if the kernel supports it. Set the same value on the client.
Defaults to unset.

=head2 NFS_KRB5_FLAVORS

Comma separated Kerberos security flavors to export and test. Set the same
value on the client.
Defaults to C<krb5,krb5i,krb5p>.

=head2 NFS_OPTIONS

Export options applied to synchronous exports.
Defaults to C<rw,sync,no_root_squash>.

=head2 NFS_OPTIONS_ASYNC

Export options applied to asynchronous exports.
Defaults to C<rw,async,no_root_squash>.

=head1 Barriers

=head2 NFS_SERVER_ENABLED

Signals that the NFS server is up and all exports are active.
With C<NFS_KRB5>, the KDC is ready too.

=head2 NFS_CLIENT_ENABLED

Waits for the client to finish mounting all exports; test data is written after this point.

=head2 NFS_SERVER_CHECK

Both nodes meet here after all checksum verifications are complete.

=cut
