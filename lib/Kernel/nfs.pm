# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package Kernel::nfs;

use Exporter 'import';

use strict;
use warnings;
use testapi;
use package_utils;
use Kernel::net_tests qw(start_packet_capture stop_packet_capture count_capture_packets capture_statistics);
use Kernel::block_dev qw(start_block_trace stop_block_trace count_block_writes);

our @EXPORT = qw(
  create_export
  setup_pnfs_client
  verify_pnfs_block_layout
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

=head2 verify_pnfs_block_layout

  verify_pnfs_block_layout($server, $export, $mountpoint, $dev);

Verify that a pNFS block layout carries the data. Write a 4K probe file over
NFS while capturing both the NFS traffic and the requests of the block device
backing the export, then record the counters:
- C<server>: NFS server to mount from
- C<export>: exported path to mount
- C<mountpoint>: where to mount it, has to be free again afterwards
- C<dev>: block device backing the export

With a working block layout the client writes to the block device on its own
and only the layout operations reach the server, so no NFS WRITE operation
must show up while the block device must see the write. The check has to run
after the NFS grace period, during the grace LAYOUTGET is answered with
NFS4ERR_GRACE and the client falls back to regular NFS writes.

Products without the capture tools are reported and skipped.

=cut

sub verify_pnfs_block_layout {
    my ($server, $export, $mountpoint, $dev) = @_;
    my $pcap = '/opt/nfs.pcap.pnfs';
    my $blkparse_log = '/opt/blkparse.pnfs.log';

    install_available_packages('wireshark blktrace tcpdump');
    my $missing = script_output('for c in tshark tcpdump blktrace blkparse; do command -v $c >/dev/null || echo $c; done', proceed_on_failure => 1);
    if ($missing =~ /\w/) {
        record_info('pNFS traffic skipped', "Capture tools not available on this product: $missing", result => 'softfail');
        return;
    }
    assert_script_run("mount -t nfs4 -o vers=4.1,minorversion=1 $server:$export $mountpoint");
    start_packet_capture('lo', $pcap, 'port 2049');
    start_block_trace($dev, $blkparse_log);
    sleep 5;
    record_info('capture env', script_output("mountpoint /sys/kernel/debug; ls -l $pcap; ps -ef | grep -e '[t]cpdump' -e '[b]lktrace'; cat $pcap.log", proceed_on_failure => 1));
    script_run("xfs_io -f -c \"pwrite 0 4K\" $mountpoint/pnfs_probe");
    script_run('sync');
    sleep 2;
    stop_packet_capture;
    stop_block_trace;
    my $nfs_packets = count_capture_packets($pcap, 'nfs');
    my $nfs_writes = count_capture_packets($pcap, 'nfs.opcode == 38');
    my $blk_writes = count_block_writes($blkparse_log);
    record_info('pNFS traffic', "NFS packets: $nfs_packets\nNFS WRITE operations: $nfs_writes\nblock write requests: $blk_writes\n\n" . capture_statistics($pcap), result => ($nfs_packets > 0 && $nfs_writes == 0 && $blk_writes > 0) ? 'ok' : 'fail');
    upload_logs($pcap, failok => 1);
    upload_logs($blkparse_log, failok => 1);
    script_run("rm -f $mountpoint/pnfs_probe");
    assert_script_run("umount $mountpoint");
}




1;
