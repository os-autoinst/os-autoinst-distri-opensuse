# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package Kernel::nfs;

use base Exporter;

use strict;
use warnings;
use testapi;

our @EXPORT = qw(
  mount_share
  create_mount_and_export
  nfs_verify_checksums
  nfs_export_path
  nfs_local_path
);

=head1 SYNOPSIS

Shared helpers for kernel NFS tests.

=cut

=head2 mount_share

    mount_share($server, $share, $local, $opts);

Creates a local directory and mounts an NFS share with the given options.

=cut

sub mount_share {
    my ($server, $share, $local, $opts) = @_;

    assert_script_run("mkdir -p $local");
    assert_script_run("mount -t nfs -o $opts $server:$share $local");
}

=head2 create_mount_and_export

    create_mount_and_export($mountpoint, $client, $permissions);

Create a server export directory and add it to F</etc/exports>.

=cut

sub create_mount_and_export {
    my ($mountpoint, $client, $permissions) = @_;

    assert_script_run("mkdir -p $mountpoint");
    assert_script_run("chmod 777 $mountpoint");
    assert_script_run("echo $mountpoint $client\\($permissions\\) >> /etc/exports");
}

=head2 nfs_verify_checksums

    nfs_verify_checksums($path);

Verify the checksum file created by the NFS client in the export directory.

=cut

sub nfs_verify_checksums {
    my ($path) = @_;

    record_info('NFS list files', script_output("ls -la $path"));
    assert_script_run("cd $path && md5sum -c md5sum.txt");
    record_info('NFS checksum', script_output("cat $path/md5sum.txt"));
}

=head2 nfs_export_path

    nfs_export_path(version => 'V3', async => 0);

Return the server-side export path for a given NFS version.

=cut

sub nfs_export_path {
    my %args = @_;
    my $version = $args{version} // die 'NFS version is required';
    (my $version_number = $version) =~ s/^V//;
    my $async = $args{async} // 0;
    my $suffix = $async ? '_ASYNC' : '';
    my $path_suffix = $async ? '_async' : '';

    return get_var("NFS_MOUNT_NFS$version_number$suffix", "/var/lib/nfs-tests/shared_nfs$version_number$path_suffix");
}

=head2 nfs_local_path

    nfs_local_path(version => 'V4', async => 1);

Return the client-side local mount point for a given NFS version.

=cut

sub nfs_local_path {
    my %args = @_;
    my $version = $args{version} // die 'NFS version is required';
    (my $version_number = $version) =~ s/^V//;
    my $async = $args{async} // 0;
    my $suffix = $async ? '_ASYNC' : '';
    my $path_suffix = $async ? 'async' : '';

    return get_var("NFS_LOCAL_NFS$version_number$suffix", "/var/lib/nfs-tests/localNFS$version_number$path_suffix");
}

1;
