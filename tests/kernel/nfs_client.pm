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
use Kernel::nfs qw(kernel_supports_nfs_krb5 setup_nfs_krb5_client upload_nfs_krb5_logs);

sub copy_file {
    my ($flag, $nfs_mount, $file) = @_;
    assert_script_run("dd oflag=$flag if=testfile of=$nfs_mount/$file bs=1024 count=10240");
}

sub write_test_data {
    my ($dir) = @_;

    assert_script_run("cp testfile md5sum.txt $dir");
    copy_file('direct', $dir, 'testfile_oflag_direct');
    copy_file('dsync', $dir, 'testfile_oflag_dsync');
    copy_file('sync', $dir, 'testfile_oflag_sync');
}

sub read_back_test_data {
    my ($dir) = @_;
    my ($md5) = split(/\s+/, script_output("cat $dir/md5sum.txt"));

    foreach my $file (qw(testfile testfile_oflag_direct testfile_oflag_dsync testfile_oflag_sync)) {
        my ($read_md5) = split(/\s+/, script_output("md5sum $dir/$file"));
        die "Read back of $dir/$file failed: checksum $read_md5, expected $md5" unless $read_md5 eq $md5;
    }
}

sub run {
    select_serial_terminal();
    record_info("hostname", script_output("hostname"));
    my $server_node = get_var('SERVER_NODE', 'server-node00');
    my $nfs_krb5 = 0;
    if (get_var('NFS_KRB5')) {
        $nfs_krb5 = kernel_supports_nfs_krb5();
        record_info('INFO', 'Kernel has no CONFIG_RPCSEC_GSS_KRB5, skipping NFS Kerberos tests') unless $nfs_krb5;
    }
    my @krb5_flavors = @{get_var_array('NFS_KRB5_FLAVORS', 'krb5,krb5i,krb5p')};

    install_package('nfs-client', trup_apply => 1);

    my $nfs_mount_nfs3 = get_var('NFS_MOUNT_NFS3', '/var/lib/nfs-tests/shared_nfs3');
    my $nfs_mount_nfs3_async = get_var('NFS_MOUNT_NFS3_ASYNC', '/var/lib/nfs-tests/shared_nfs3_async');
    my $nfs_mount_nfs4 = get_var('NFS_MOUNT_NFS4', '/var/lib/nfs-tests/shared_nfs4');
    my $nfs_mount_nfs4_async = get_var('NFS_MOUNT_NFS4_ASYNC', '/var/lib/nfs-tests/shared_nfs4_async');
    my $nfs_mount_nfs3_krb5 = get_var('NFS_MOUNT_NFS3_KRB5', '/var/lib/nfs-tests/shared_nfs3_krb5');
    my $nfs_mount_nfs3_krb5_async = get_var('NFS_MOUNT_NFS3_KRB5_ASYNC', '/var/lib/nfs-tests/shared_nfs3_krb5_async');
    my $nfs_mount_nfs4_krb5 = get_var('NFS_MOUNT_NFS4_KRB5', '/var/lib/nfs-tests/shared_nfs4_krb5');
    my $nfs_mount_nfs4_krb5_async = get_var('NFS_MOUNT_NFS4_KRB5_ASYNC', '/var/lib/nfs-tests/shared_nfs4_krb5_async');
    my $local_nfs3 = get_var('NFS_LOCAL_NFS3', '/var/lib/nfs-tests/localNFS3');
    my $local_nfs3_async = get_var('NFS_LOCAL_NFS3_ASYNC', '/var/lib/nfs-tests/localNFS3async');
    my $local_nfs4 = get_var('NFS_LOCAL_NFS4', '/var/lib/nfs-tests/localNFS4');
    my $local_nfs4_async = get_var('NFS_LOCAL_NFS4_ASYNC', '/var/lib/nfs-tests/localNFS4async');
    my $local_nfs3_krb5 = get_var('NFS_LOCAL_NFS3_KRB5', '/var/lib/nfs-tests/localNFS3krb5');
    my $local_nfs3_krb5_async = get_var('NFS_LOCAL_NFS3_KRB5_ASYNC', '/var/lib/nfs-tests/localNFS3krb5async');
    my $local_nfs4_krb5 = get_var('NFS_LOCAL_NFS4_KRB5', '/var/lib/nfs-tests/localNFS4krb5');
    my $local_nfs4_krb5_async = get_var('NFS_LOCAL_NFS4_KRB5_ASYNC', '/var/lib/nfs-tests/localNFS4krb5async');
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

    # Kerberos exports and mountpoints, only for NFS versions the kernel supports
    my @krb5_mounts = grep { $nfs_krb5 && $_->{supported} } (
        {
            version => 3,
            supported => $kernel_nfs3,
            sync => {export => $nfs_mount_nfs3_krb5, local => $local_nfs3_krb5},
            async => {export => $nfs_mount_nfs3_krb5_async, local => $local_nfs3_krb5_async},
        },
        {
            version => 4,
            supported => $kernel_nfs4,
            sync => {export => $nfs_mount_nfs4_krb5, local => $local_nfs4_krb5},
            async => {export => $nfs_mount_nfs4_krb5_async, local => $local_nfs4_krb5_async},
        },
    );
    # Join the realm before the first mount. The NFSv4 client state (lease) for
    # the server is set up by the first mount and shared by all later mounts,
    # thus only then the lease operations use Kerberos too.
    setup_nfs_krb5_client($server_node) if @krb5_mounts;

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
        write_test_data($local_nfs3);
        write_test_data($local_nfs3_async);
    }
    if ($kernel_nfs4 == 1) {
        write_test_data($local_nfs4);
        write_test_data($local_nfs4_async);
    }

    # Mount each Kerberos export once for each flavor and write into its own subdirectory.
    # Like for the other exports, mount the sync export with sync and the async one with defaults.
    # Then mount it again and read the data back, so the reads go over the network
    # through the Kerberos flavor too, not from the page cache.
    foreach my $mount (@krb5_mounts) {
        foreach my $type (qw(sync async)) {
            my ($export, $local) = @{$mount->{$type}}{qw(export local)};
            assert_script_run("mkdir -p $local");
            foreach my $sec (@krb5_flavors) {
                my $options = join(',', "nfsvers=$mount->{version}", ($type eq 'sync' ? 'sync' : ()), "sec=$sec");
                my $mount_cmd = "mount -t nfs -o $options $server_node:$export $local";
                record_info("NFS$mount->{version} $type $sec", $mount_cmd);
                assert_script_run($mount_cmd, timeout => 180);
                assert_script_run("findmnt -n -o OPTIONS $local | grep -w 'sec=$sec'");
                assert_script_run("mkdir -p $local/$sec");
                write_test_data("$local/$sec");
                assert_script_run("umount $local");
                assert_script_run($mount_cmd, timeout => 180);
                read_back_test_data("$local/$sec");
                assert_script_run("umount $local");
            }
        }
    }

    barrier_wait("NFS_SERVER_CHECK");
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

sub post_fail_hook {
    select_serial_terminal;
    upload_nfs_krb5_logs if get_var('NFS_KRB5');
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

With C<NFS_KRB5>, the client also joins the Kerberos realm on the server,
mounts the sync and async NFSv3 and NFSv4 Kerberos exports once for each
security flavor and writes the same test data into a subdirectory with the
name of the flavor. Then it mounts the export again and reads the data back
to check the checksums over the Kerberos flavor too.

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

=head2 NFS_MOUNT_NFS3_KRB5

Server-side export path for the NFSv3 mounts with Kerberos security flavors.
Defaults to C</var/lib/nfs-tests/shared_nfs3_krb5>.

=head2 NFS_MOUNT_NFS3_KRB5_ASYNC

Server-side export path for the asynchronous NFSv3 mounts with Kerberos
security flavors. Defaults to C</var/lib/nfs-tests/shared_nfs3_krb5_async>.

=head2 NFS_MOUNT_NFS4_KRB5

Server-side export path for the NFSv4 mounts with Kerberos security flavors.
Defaults to C</var/lib/nfs-tests/shared_nfs4_krb5>.

=head2 NFS_MOUNT_NFS4_KRB5_ASYNC

Server-side export path for the asynchronous NFSv4 mounts with Kerberos
security flavors. Defaults to C</var/lib/nfs-tests/shared_nfs4_krb5_async>.

=head2 NFS_KRB5

When set to C<1>, also test NFSv3 and NFSv4 with Kerberos. Set the same value on the
server. See L<tests/kernel/nfs_server.pm>.
Defaults to unset.

=head2 NFS_KRB5_FLAVORS

Comma separated Kerberos security flavors to mount and test. Set the same
value on the server.
Defaults to C<krb5,krb5i,krb5p>.

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

=head2 NFS_LOCAL_NFS3_KRB5

Local mountpoint for the NFSv3 export with Kerberos security flavors.
Defaults to C</var/lib/nfs-tests/localNFS3krb5>.

=head2 NFS_LOCAL_NFS3_KRB5_ASYNC

Local mountpoint for the asynchronous NFSv3 export with Kerberos security
flavors. Defaults to C</var/lib/nfs-tests/localNFS3krb5async>.

=head2 NFS_LOCAL_NFS4_KRB5

Local mountpoint for the NFSv4 export with Kerberos security flavors.
Defaults to C</var/lib/nfs-tests/localNFS4krb5>.

=head2 NFS_LOCAL_NFS4_KRB5_ASYNC

Local mountpoint for the asynchronous NFSv4 export with Kerberos security
flavors. Defaults to C</var/lib/nfs-tests/localNFS4krb5async>.

=head2 NFS_MULTIPATH

When set to C<1>, enables multipath for NFS mounts.
Defaults to C<0>.

=head1 Barriers

=head2 NFS_SERVER_ENABLED

Waits for the server to be ready before mounting the exports.
With C<NFS_KRB5>, the KDC on the server is ready after this point.

=head2 NFS_CLIENT_ENABLED

Signals that all NFS exports are mounted; test data is written after this point.

=head2 NFS_SERVER_CHECK

Signals that the client has finished writing test data; the server proceeds to verify checksums after this point.

=cut
