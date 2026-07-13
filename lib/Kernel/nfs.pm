# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package Kernel::nfs;

use Exporter;

use strict;
use warnings;
use testapi;
use version_utils qw(is_sle);

our @EXPORT = qw(
  create_export
  get_nfs_versions
  nfs_mount_config
);

=head1 SYNOPSIS

Utils and helpers for nfs testing

=cut

=head2 create_export

  create_export();

Create an NFS share and export it with specified settings:
- C<path>: Filesystem path to export
- C<cl>: client IP/hostname to create the share for
- C<options>: options to record in /etc/exports

=cut

sub create_export {
    my ($path, $cl, $options) = @_;

    assert_script_run "mkdir -p $path";
    assert_script_run "chmod 777 $path";
    assert_script_run "echo $path $cl\\($options\\) >> /etc/exports";
}

=head2 get_nfs_versions

  get_nfs_versions();

Returns the list of NFS versions (e.g. C<3>, C<4.0>, C<4.1>, C<4.2>) that
should be tested on the current SUT.

Can be overridden with the C<NFS_VERSIONS> openQA variable (comma-separated
list, takes precedence over everything else), or narrowed down with
C<NFS_VERSIONS_SKIP> (comma-separated list of versions to leave out).

=cut

sub get_nfs_versions {
    return split(/,/, get_var('NFS_VERSIONS')) if get_var('NFS_VERSIONS');

    # NFS versions supported by every currently tested product
    my @versions = ('3', '4.0', '4.1');

    # nfsd on SLE12-SP5 has no support for NFS 4.2
    push @versions, '4.2' unless is_sle('12-sp5');

    my @skip_versions = split(/,/, get_var('NFS_VERSIONS_SKIP', ''));

    my @result;
    for my $version (@versions) {
        next if grep { $_ eq $version } @skip_versions;
        push @result, $version;
    }

    return @result;
}

=head2 nfs_mount_config

  nfs_mount_config();

Returns a hashref with the paths used to export/mount a given NFS version:
C<remote>, C<remote_async>, C<local>, C<local_async>. Every path can be
overridden with the corresponding C<NFS_MOUNT_NFS*> / C<NFS_LOCAL_NFS*>
openQA variable, e.g. C<NFS_MOUNT_NFS4_2> or C<NFS_LOCAL_NFS4_2_ASYNC>.

=cut

sub nfs_mount_config {
    my ($version) = @_;

    my $slug = $version;
    $slug =~ s/\./_/g;

    return {
        remote => get_var("NFS_MOUNT_NFS$slug", "/var/lib/nfs-tests/shared_nfs$slug"),
        remote_async => get_var("NFS_MOUNT_NFS${slug}_ASYNC", "/var/lib/nfs-tests/shared_nfs${slug}_async"),
        local => get_var("NFS_LOCAL_NFS$slug", "/var/lib/nfs-tests/localNFS$slug"),
        local_async => get_var("NFS_LOCAL_NFS${slug}_ASYNC", "/var/lib/nfs-tests/localNFS${slug}async"),
    };
}

1;
