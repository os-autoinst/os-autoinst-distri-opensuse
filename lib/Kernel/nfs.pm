# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package Kernel::nfs;

use Exporter 'import';

use strict;
use warnings;
use testapi;

our @EXPORT = qw(
  create_export
  setup_pnfs_client
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

=head2 setup_pnfs_client

  setup_pnfs_client();

Prepare a client for a pNFS block layout. Enable nfs-blkmap.service, blkmapd
is required to resolve the block devices of a layout, and blacklist the
flexfiles layout driver so it never silently replaces the block layout.

=cut

sub setup_pnfs_client {
    assert_script_run('echo "blacklist nfs_layout_flexfiles" >> /etc/modprobe.d/blacklist.conf && echo "install nfs_layout_flexfiles /bin/false" >> /etc/modprobe.d/blacklist.conf');
    script_run('modprobe -r nfs_layout_flexfiles');
    assert_script_run('systemctl enable --now nfs-blkmap.service');
    record_info('blkmapd', script_output('systemctl --no-pager status nfs-blkmap.service', proceed_on_failure => 1));
}




1;
