# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package Kernel::nfs;

use Exporter 'import';

use strict;
use warnings;
use testapi;
use package_utils;
use utils 'systemctl';
use List::Util 'uniq';
use File::Basename qw(basename dirname);
use Kernel::krb5 qw(setup_krb5_conf setup_krb5_kdc add_host_principals);
use Kernel::net_tests qw(start_packet_capture stop_packet_capture count_capture_packets capture_statistics);
use Kernel::block_dev qw(start_block_trace stop_block_trace count_block_writes);
use Kernel::utils qw(start_trace_events save_trace);

our @EXPORT = qw(
  create_export
  get_export_paths
  setup_pnfs_client
  verify_pnfs_block_layout
  start_pnfs_debug
  stop_pnfs_debug
  collect_pnfs_debug
  kernel_supports_nfs_krb5
  setup_nfs_krb5_server
  setup_nfs_krb5_client
  upload_nfs_krb5_logs
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

=head2 get_export_paths

  my @paths = get_export_paths();

Returns the paths exported in /etc/exports, each path once, in the order
of the file. Comments and empty lines are skipped.

=cut

sub get_export_paths {
    my $exports = script_output('cat /etc/exports');
    return uniq map { m{^(/\S+)} ? $1 : () } split /\n/, $exports;
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

# Layout operations of the pNFS client and server and the block I/O, see
# start_pnfs_debug()
my @PNFS_TRACE_EVENTS = qw(
  nfs4/nfs4_layoutget nfs4/pnfs_update_layout nfs4/nfs4_layoutcommit
  nfs4/nfs4_layoutreturn nfs4/nfs4_layouterror nfs4/nfs4_getdeviceinfo
  nfs4/nfs4_pnfs_read nfs4/nfs4_pnfs_write nfs4/pnfs_mds_fallback_*
  nfsd/nfsd_layout* block/block_bio_queue block/block_rq_complete
);
my $pnfs_block_filter;

=head2 start_pnfs_debug

  start_pnfs_debug($dir);

Start to collect pNFS block layout debug data into C<$dir>, old data in
C<$dir> is removed:
- capture the NFS traffic on lo. Over RDMA the capture stays empty, rxe loops
  back the packets inside the kernel
- trace the layout operations of client and server, and the block I/O of the
  devices below the exports in F</etc/exports>

Use C<collect_pnfs_debug> to keep the data, C<stop_pnfs_debug> to drop it.
The trace keeps running between the calls, each call starts with an empty
trace. This keeps the call before each subtest short.

=cut

sub start_pnfs_debug {
    my ($dir) = @_;

    # Kernel dev_t of the export devices, (major << 20) | minor. They do not
    # change during a test run.
    unless (defined $pnfs_block_filter) {
        my $cmd = 'for p in ' . join(' ', get_export_paths()) . '; do d=$(findmnt -nvo SOURCE --target $p); ';
        $cmd .= '[ -b "$d" ] && echo $(((0x$(stat -c %t $d) << 20) | 0x$(stat -c %T $d))); done; true';
        $pnfs_block_filter = join(' || ', map { "dev == $_" } split(/\s+/, script_output($cmd, proceed_on_failure => 1)));
    }
    my @events = $pnfs_block_filter ? @PNFS_TRACE_EVENTS : grep { !m{^block/} } @PNFS_TRACE_EVENTS;
    my %filters = $pnfs_block_filter ? map { $_ => $pnfs_block_filter } qw(block/block_bio_queue block/block_rq_complete) : ();

    script_run("rm -rf $dir; mkdir -p $dir");
    # Keep the metadata operations, but do not fill the disk when I/O falls
    # back to NFS
    start_packet_capture('lo', "$dir/nfs.pcap", 'port 2049', snaplen => 4096);
    start_trace_events(\@events, filters => \%filters);
}

=head2 stop_pnfs_debug

  stop_pnfs_debug();

Stop the packet capture started by C<start_pnfs_debug>. The trace keeps
running, the next C<start_pnfs_debug> clears it.

=cut

sub stop_pnfs_debug {
    stop_packet_capture;
}

=head2 collect_pnfs_debug

  collect_pnfs_debug($dir, $tarball, @ios);

Keep the pNFS debug data started by C<start_pnfs_debug> after a failure and
pack C<$dir> into C<$tarball>. Each element of C<@ios> is a failed I/O to
repeat while the capture still runs:

  {path => '/opt/nfs/scratch/file2', op => 'read', offset => 413696, len => 1024,
   export_path => '/opt/export/scratch/file2', mnt => '/opt/nfs/scratch',
   nfs_dev => 'server:/opt/export/scratch', mount_opts => '-o vers=4.1'}

The I/O is repeated on the exported file (as the server sees it), on the
block device at the offset from C<xfs_bmap> (as the pNFS block layout client
does it) and over NFS, see repeat_io.log. The layout operations of the
capture are decoded to layout_ops.log.

=cut

sub collect_pnfs_debug {
    my ($dir, $tarball, @ios) = @_;

    repeat_pnfs_io($dir, $_) foreach @ios;
    stop_packet_capture;
    save_trace("$dir/trace.log");
    script_run("{ uname -a; cat /proc/fs/nfsfs/servers /proc/self/mountstats; mount; losetup -a; nfsstat -c; systemctl --no-pager status nfs-blkmap.service; } > $dir/env.log 2>&1");
    script_run("dmesg > $dir/dmesg.log");
    # GETDEVICEINFO, LAYOUTCOMMIT, LAYOUTGET and LAYOUTRETURN with the extents
    script_run("test -s $dir/nfs.pcap && tshark -nr $dir/nfs.pcap -V -Y 'nfs.opcode == 47 || nfs.opcode == 49 || nfs.opcode == 50 || nfs.opcode == 51' > $dir/layout_ops.log 2>&1");
    script_run("tar -czf $tarball -C " . dirname($dir) . ' ' . basename($dir), timeout => 300);
}

sub repeat_pnfs_io {
    my ($dir, $io) = @_;
    my $log = "$dir/repeat_io.log";
    my ($file, $offset, $len) = @$io{qw(export_path offset len)};
    my $aligned = int($offset / 4096) * 4096;

    script_run("echo '=== $io->{op} offset=$offset buflen=$len on $io->{path}' >> $log");
    script_run("{ echo '--- exported file $file'; stat $file; xfs_bmap -vp $file; xfs_io -r -c 'pread $offset $len' $file; xfs_io -d -r -c 'pread $aligned 4096' $file; } >> $log 2>&1");

    # xfs_bmap -v prints [start..end] of the file and of the device in 512
    # byte units, take the device range of the extent that holds the offset
    my $dev = script_output("findmnt -nvo SOURCE --target $file", proceed_on_failure => 1);
    my $sector = int($offset / 512);
    foreach (split(/\n/, script_output("xfs_bmap -v $file", proceed_on_failure => 1))) {
        next unless /\[(\d+)\.\.(\d+)\]:\s+(\d+)\.\./ && $sector >= $1 && $sector <= $2;
        my $dev_offset = $3 * 512 + $offset - $1 * 512;
        my $dev_aligned = int($dev_offset / 4096) * 4096;
        script_run("{ echo '--- block device $dev offset $dev_offset'; dd if=$dev of=/dev/null iflag=skip_bytes,count_bytes skip=$dev_offset count=$len; echo dd exit: \$?; dd if=$dev of=/dev/null iflag=direct,skip_bytes,count_bytes skip=$dev_aligned count=4096; echo dd direct exit: \$?; } >> $log 2>&1");
    }

    my $mounted = script_run("mountpoint -q $io->{mnt}") == 0;
    script_run("mount -t nfs $io->{mount_opts} $io->{nfs_dev} $io->{mnt}") unless $mounted;
    script_run('echo 3 > /proc/sys/vm/drop_caches');
    script_run("{ echo '--- NFS $io->{path}'; strace -tt -e trace=%file,%desc -o $dir/repeat_io.$offset.strace xfs_io -r -c 'pread $offset $len' $io->{path}; echo buffered pread exit: \$?; xfs_io -d -r -c 'pread $aligned 4096' $io->{path}; echo direct pread exit: \$?; } >> $log 2>&1");
    script_run("umount $io->{mnt}") unless $mounted;
}

=head2 kernel_supports_nfs_krb5

  my $supported = kernel_supports_nfs_krb5();

Return 1 if the running kernel supports RPCSEC_GSS with Kerberos
(C<CONFIG_RPCSEC_GSS_KRB5>), else 0. Kerberos works with all NFS
versions, the caller decides which versions to test.

=cut

sub kernel_supports_nfs_krb5 {
    return script_run('zgrep "CONFIG_RPCSEC_GSS_KRB5=[my]" /proc/config.gz') == 0 ? 1 : 0;
}

=head2 setup_nfs_krb5_server

  setup_nfs_krb5_server([%realm_settings]);

Prepare this node as KDC and Kerberos NFS server. Set up the realm with this
node as KDC, add the C<nfs> service principals of this node and start the
server side GSS service. Optional realm settings are passed to
L<Kernel::krb5>, see there. Call it before C<nfs-server> starts, so C<nfsd>
uses the GSS service from the start.

The GSS service is C<gssproxy> where it is installed, else C<rpc-svcgssd>.
Only one of them runs, else the kernel can use either of them. Both need
the C<auth_rpcgss> module loaded when they start: C<rpc.svcgssd> exits
without it, and C<gssproxy> needs it to make the kernel use it instead of
C<rpc-svcgssd>.

The function makes sure that the GSS service runs and, for C<gssproxy>, that
the kernel uses it. A restart alone does not show this: the service units
ignore a failed start (C<ExecStart=->) and are skipped without a keytab.

=cut

sub setup_nfs_krb5_server {
    my (%args) = @_;

    install_package('krb5-server krb5-client', trup_apply => 1);
    setup_krb5_conf(script_output('hostname'), %args);
    setup_krb5_kdc(%args);
    add_host_principals('nfs', %args);

    # Workaround: gssproxy and rpc.svcgssd need the auth_rpcgss module, which
    # nfsd loads only later. Load it here until lib/Kernel provides kernel
    # module operations, see poo#207906.
    assert_script_run('modprobe auth_rpcgss');
    if (script_run('systemctl cat gssproxy.service > /dev/null 2>&1') == 0) {
        systemctl('restart gssproxy');
        systemctl('is-active gssproxy');
        assert_script_run('grep -qx 1 /proc/net/rpc/use-gss-proxy');
    } else {
        systemctl('restart rpc-svcgssd');
        systemctl('is-active rpc-svcgssd');
    }
    record_info('GSS server', script_output('systemctl --no-pager status gssproxy rpc-svcgssd; cat /proc/net/rpc/use-gss-proxy', proceed_on_failure => 1));
}

=head2 setup_nfs_krb5_client

  setup_nfs_krb5_client($kdc [, %realm_settings]);

Prepare this node as Kerberos NFS client of the realm on C<kdc>. Add the
C<nfs> service principals of this node through C<kadmind> on C<kdc> and
restart C<rpc-gssd> and make sure that it runs. The KDC has to be ready, see
C<setup_nfs_krb5_server()>.
Pass the same realm settings as on the server.

Before the mounts, check the Kerberos setup in user space: get a ticket with
the key of this node and a service ticket for C<nfs/>I<kdc>. Thus a failure
in the realm setup fails here, not as a failed mount that looks like a
kernel issue. C<kdc> must be the name that the client mounts the server by.

=cut

sub setup_nfs_krb5_client {
    my ($kdc, %args) = @_;

    install_package('krb5-client', trup_apply => 1);
    setup_krb5_conf($kdc, %args);
    add_host_principals('nfs', %args, remote => 1);
    systemctl('restart rpc-gssd');
    systemctl('is-active rpc-gssd');
    record_info('GSS client', script_output('systemctl --no-pager status rpc-gssd', proceed_on_failure => 1));

    # Get a ticket with the key of this node and a service ticket for the
    # server, as rpc.gssd does for the mounts. A failure here is a setup issue.
    my $host = script_output('hostname');
    assert_script_run("kinit -k nfs/$host");
    assert_script_run("kvno nfs/$kdc");
    script_run('kdestroy');
}

=head2 upload_nfs_krb5_logs

  upload_nfs_krb5_logs();

Upload the logs to debug NFS with Kerberos: the keytab entries, the journal
of the GSS and Kerberos services and the KDC and C<kadmind> logs. Missing
logs are skipped, thus it works on the server and on the client, also in a
C<post_fail_hook>.

=cut

sub upload_nfs_krb5_logs {
    script_run('klist -ke /etc/krb5.keytab > /tmp/nfs_krb5_keytab.txt 2>&1');
    script_run('journalctl --no-pager -u rpc-gssd -u rpc-svcgssd -u gssproxy -u krb5kdc -u kadmind > /tmp/nfs_krb5_journal.txt 2>&1');
    upload_logs($_, failok => 1) foreach (qw(/tmp/nfs_krb5_keytab.txt /tmp/nfs_krb5_journal.txt /var/log/krb5/krb5kdc.log /var/log/krb5/kadmind.log));
}

1;
